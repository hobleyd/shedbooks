// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

// Integration test — runs against a real PostgreSQL database and is skipped
// unless TEST_DB_HOST is set. To run it against a throwaway container:
//
//   docker run -d --rm --name shedbooks-test-db -p 55432:5432 \
//     -e POSTGRES_USER=shedbooks -e POSTGRES_PASSWORD=test \
//     -e POSTGRES_DB=shedbooks_test postgres:16-alpine
//   TEST_DB_HOST=localhost TEST_DB_PORT=55432 TEST_DB_NAME=shedbooks_test \
//     TEST_DB_USER=shedbooks TEST_DB_PASSWORD=test \
//     dart test test/infrastructure/repositories
//
// Never point it at a database holding real data: it applies every migration
// and writes rows it does not clean up.

import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/entities/transaction_line.dart';
import 'package:shedbooks_server/infrastructure/database/database_migrator.dart';
import 'package:shedbooks_server/infrastructure/repositories/postgres_transaction_repository.dart';

void main() {
  final String? host = Platform.environment['TEST_DB_HOST'];

  group('PostgresTransactionRepository split transactions', () {
    late Pool pool;
    late PostgresTransactionRepository sut;
    late String contactId;
    late String glA;
    late String glB;

    const tEntityId = 'split-it-entity';
    const tOtherEntityId = 'split-it-other-entity';
    final tDate = DateTime.utc(2026, 5, 1);
    int receiptSeq = 0;

    Future<String> insertReturningId(String sql, Map<String, dynamic> params) async {
      final Result result = await pool.execute(Sql.named(sql), parameters: params);
      return result.first.toColumnMap()['id'].toString();
    }

    List<TransactionLine> lines(List<int> amounts) => [
          for (int i = 0; i < amounts.length; i++)
            TransactionLine(
              generalLedgerId: i.isEven ? glA : glB,
              amount: amounts[i],
              gstAmount: amounts[i] ~/ 10,
              description: 'line ${i + 1}',
            ),
        ];

    Future<List<Transaction>> createSplit(List<int> amounts, {String? entityId}) =>
        sut.createSplit(
          entityId: entityId ?? tEntityId,
          contactId: contactId,
          transactionType: TransactionType.debit,
          receiptNumber: 'IT-${++receiptSeq}',
          paymentReference: null,
          transactionDate: tDate,
          lines: lines(amounts),
        );

    Future<Transaction> createSingle() => sut.create(
          entityId: tEntityId,
          contactId: contactId,
          generalLedgerId: glA,
          amount: 700,
          gstAmount: 70,
          transactionType: TransactionType.debit,
          receiptNumber: 'IT-${++receiptSeq}',
          description: 'single',
          transactionDate: tDate,
        );

    setUpAll(() async {
      pool = Pool.withEndpoints(
        [
          Endpoint(
            host: host!,
            port: int.parse(Platform.environment['TEST_DB_PORT'] ?? '5432'),
            database: Platform.environment['TEST_DB_NAME'] ?? 'shedbooks_test',
            username: Platform.environment['TEST_DB_USER'] ?? 'shedbooks',
            password: Platform.environment['TEST_DB_PASSWORD'],
          ),
        ],
        settings: const PoolSettings(maxConnectionCount: 4, sslMode: SslMode.disable),
      );
      await DatabaseMigrator(pool).migrate();
      sut = PostgresTransactionRepository(pool);

      contactId = await insertReturningId(
        "INSERT INTO contacts (entity_id, name, contact_type, gst_registered) "
        "VALUES (@e, 'Split IT Contact', 'company', TRUE) RETURNING id",
        {'e': tEntityId},
      );
      glA = await insertReturningId(
        "INSERT INTO general_ledger (entity_id, label, description, gst_applicable, direction) "
        "VALUES (@e, @label, 'Materials', TRUE, 'money_out') RETURNING id",
        {'e': tEntityId, 'label': 'IT-A-${DateTime.now().microsecondsSinceEpoch}'},
      );
      glB = await insertReturningId(
        "INSERT INTO general_ledger (entity_id, label, description, gst_applicable, direction) "
        "VALUES (@e, @label, 'Tools', FALSE, 'money_out') RETURNING id",
        {'e': tEntityId, 'label': 'IT-B-${DateTime.now().microsecondsSinceEpoch}'},
      );
    });

    tearDownAll(() async {
      await pool.close();
    });

    test('createSplit writes one row per line sharing a split group, in line order', () async {
      // Act
      final created = await createSplit([10000, 5000, 2500]);

      // Assert
      expect(created.length, 3);
      expect(created.map((t) => t.splitGroupId).toSet().length, 1);
      expect(created.first.splitGroupId, isNotNull);
      expect(created.map((t) => t.splitLineNo), [1, 2, 3]);
      expect(created.map((t) => t.amount), [10000, 5000, 2500]);
      expect(created.map((t) => t.gstAmount), [1000, 500, 250]);
      expect(created.map((t) => t.generalLedgerId), [glA, glB, glA]);
      expect(created.map((t) => t.description), ['line 1', 'line 2', 'line 3']);
      expect(created.every((t) => !t.bankMatched && t.abaBatchName == null), isTrue);

      final found = await sut.findBySplitGroup(created.first.splitGroupId!, entityId: tEntityId);
      expect(found.map((t) => t.id), created.map((t) => t.id));
    });

    test('createSplit writes nothing when any line fails (atomic)', () async {
      // Arrange
      final badLines = [
        TransactionLine(generalLedgerId: glA, amount: 100, gstAmount: 0),
        const TransactionLine(
          generalLedgerId: '00000000-0000-0000-0000-00000000dead',
          amount: 100,
          gstAmount: 0,
        ),
      ];
      const receipt = 'IT-ATOMIC';

      // Act
      Object? error;
      try {
        await sut.createSplit(
          entityId: tEntityId,
          contactId: contactId,
          transactionType: TransactionType.debit,
          receiptNumber: receipt,
          transactionDate: tDate,
          lines: badLines,
        );
      } catch (e) {
        error = e;
      }

      // Assert
      expect(error, isNotNull);
      final all = await sut.findAll(entityId: tEntityId);
      expect(all.where((t) => t.receiptNumber == receipt), isEmpty);
    });

    test('findAll returns the lines of a split in line order', () async {
      // Arrange
      final created = await createSplit([300, 200, 100]);

      // Act
      final all = await sut.findAll(entityId: tEntityId);

      // Assert
      final group = all.where((t) => t.splitGroupId == created.first.splitGroupId);
      expect(group.map((t) => t.splitLineNo), [1, 2, 3]);
    });

    test('bankMatch on one line matches every line of the split and nothing else', () async {
      // Arrange
      final split = await createSplit([10000, 5000]);
      final otherSplit = await createSplit([400, 600]);
      final single = await createSingle();

      // Act
      await sut.bankMatch(
        [split.last.id],
        entityId: tEntityId,
        transactionDate: DateTime.utc(2026, 5, 3),
      );

      // Assert
      final matched = await sut.findBySplitGroup(split.first.splitGroupId!, entityId: tEntityId);
      expect(matched.every((t) => t.bankMatched), isTrue);
      expect(matched.every((t) => t.transactionDate == DateTime.utc(2026, 5, 3)), isTrue);
      final untouched =
          await sut.findBySplitGroup(otherSplit.first.splitGroupId!, entityId: tEntityId);
      expect(untouched.any((t) => t.bankMatched), isFalse);
      expect((await sut.findById(single.id, entityId: tEntityId))!.bankMatched, isFalse);
    });

    test('bankMatch on an ordinary transaction does not touch other ordinary transactions', () async {
      // Arrange
      final a = await createSingle();
      final b = await createSingle();

      // Act
      await sut.bankMatch([a.id], entityId: tEntityId);

      // Assert
      expect((await sut.findById(a.id, entityId: tEntityId))!.bankMatched, isTrue);
      expect((await sut.findById(b.id, entityId: tEntityId))!.bankMatched, isFalse);
    });

    test('stampAbaBatch on one line stamps every line of the split', () async {
      // Arrange
      final split = await createSplit([10000, 5000]);
      final single = await createSingle();

      // Act
      await sut.stampAbaBatch([split.first.id], 'WMS260501001', entityId: tEntityId);

      // Assert
      final stamped = await sut.findBySplitGroup(split.first.splitGroupId!, entityId: tEntityId);
      expect(stamped.map((t) => t.abaBatchName), ['WMS260501001', 'WMS260501001']);
      expect((await sut.findById(single.id, entityId: tEntityId))!.abaBatchName, isNull);
    });

    test('replaceWithLines swaps the split for new lines, carrying match state over', () async {
      // Arrange
      final split = await createSplit([10000, 5000]);

      // Act
      final replaced = await sut.replaceWithLines(
        replacedIds: split.map((t) => t.id).toList(),
        entityId: tEntityId,
        contactId: contactId,
        transactionType: TransactionType.debit,
        receiptNumber: split.first.receiptNumber,
        transactionDate: tDate,
        bankMatched: true,
        abaBatchName: 'WMS260501002',
        lines: lines([6000, 5000, 4000]),
      );

      // Assert
      expect(replaced.length, 3);
      expect(replaced.map((t) => t.splitLineNo), [1, 2, 3]);
      expect(replaced.first.splitGroupId, isNot(split.first.splitGroupId));
      expect(replaced.every((t) => t.bankMatched), isTrue);
      expect(replaced.every((t) => t.abaBatchName == 'WMS260501002'), isTrue);
      expect(replaced.map((t) => t.id).toSet().intersection(split.map((t) => t.id).toSet()),
          isEmpty);
      for (final Transaction old in split) {
        expect(await sut.findById(old.id, entityId: tEntityId), isNull);
      }
      expect(await sut.findBySplitGroup(split.first.splitGroupId!, entityId: tEntityId), isEmpty);
    });

    test('replaceWithLines with one line collapses the split to an ordinary transaction', () async {
      // Arrange
      final split = await createSplit([10000, 5000]);

      // Act
      final replaced = await sut.replaceWithLines(
        replacedIds: split.map((t) => t.id).toList(),
        entityId: tEntityId,
        contactId: contactId,
        transactionType: TransactionType.debit,
        receiptNumber: split.first.receiptNumber,
        transactionDate: tDate,
        lines: lines([15000]),
      );

      // Assert
      expect(replaced.single.splitGroupId, isNull);
      expect(replaced.single.splitLineNo, isNull);
      expect(replaced.single.amount, 15000);
    });

    test('deleteSplitGroup soft-deletes every line and is scoped to the entity', () async {
      // Arrange
      final split = await createSplit([10000, 5000]);
      final String groupId = split.first.splitGroupId!;

      // Act — wrong entity first: must delete nothing.
      await sut.deleteSplitGroup(groupId, entityId: tOtherEntityId);
      final afterWrongEntity = await sut.findBySplitGroup(groupId, entityId: tEntityId);
      await sut.deleteSplitGroup(groupId, entityId: tEntityId);

      // Assert
      expect(afterWrongEntity.length, 2);
      expect(await sut.findBySplitGroup(groupId, entityId: tOtherEntityId), isEmpty);
      expect(await sut.findBySplitGroup(groupId, entityId: tEntityId), isEmpty);
    });

    test('create still writes an ordinary transaction with no split fields', () async {
      // Act
      final single = await createSingle();

      // Assert
      expect(single.splitGroupId, isNull);
      expect(single.splitLineNo, isNull);
      expect(single.isSplit, isFalse);
    });
  }, skip: host == null ? 'TEST_DB_HOST not set — needs a real PostgreSQL database' : null);
}
