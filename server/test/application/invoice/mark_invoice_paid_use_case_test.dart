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

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/invoice.dart';
import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/repositories/i_invoice_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/invoice/mark_invoice_paid_use_case.dart';

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}
class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockInvoiceRepository invoiceRepo;
  late MockTransactionRepository transactionRepo;
  late MarkInvoicePaidUseCase sut;

  const tEntityId = 'entity-1';
  const tInvoiceId = '00000000-0000-0000-0000-000000000030';
  const tContactId = '00000000-0000-0000-0000-000000000010';
  const tGlId1 = '00000000-0000-0000-0000-000000000021';
  const tGlId2 = '00000000-0000-0000-0000-000000000022';
  const tTxId1 = '00000000-0000-0000-0000-000000000041';
  const tTxId2 = '00000000-0000-0000-0000-000000000042';
  final tTransactionDate = DateTime.utc(2026, 6, 15);
  final tNow = DateTime.utc(2026, 6, 1);

  final tLineItem1 = InvoiceLineItem(
    id: '00000000-0000-0000-0000-000000000031',
    invoiceId: tInvoiceId,
    description: 'Annual membership',
    generalLedgerId: tGlId1,
    amountCents: 5000,
    gstCents: 500,
    createdAt: tNow,
  );

  final tLineItem2 = InvoiceLineItem(
    id: '00000000-0000-0000-0000-000000000032',
    invoiceId: tInvoiceId,
    description: 'Tool fee',
    generalLedgerId: tGlId2,
    amountCents: 2000,
    gstCents: 200,
    createdAt: tNow,
  );

  Invoice _makeInvoice({
    DateTime? paidAt,
    List<InvoiceLineItem> lineItems = const [],
  }) =>
      Invoice(
        id: tInvoiceId,
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-001',
        invoiceDate: DateTime.utc(2026, 6, 1),
        contactId: tContactId,
        totalAmountCents: 7000,
        totalGstCents: 700,
        paidAt: paidAt,
        createdAt: tNow,
        updatedAt: tNow,
        lineItems: lineItems,
      );

  Transaction _makeTx(String id, String glId, int amount, int gst) =>
      Transaction(
        id: id,
        contactId: tContactId,
        generalLedgerId: glId,
        amount: amount,
        gstAmount: gst,
        transactionType: TransactionType.credit,
        receiptNumber: 'WMS-26-001',
        description: '',
        transactionDate: tTransactionDate,
        createdAt: tNow,
        updatedAt: tNow,
        bankMatched: false,
      );

  setUp(() {
    invoiceRepo = MockInvoiceRepository();
    transactionRepo = MockTransactionRepository();
    sut = MarkInvoicePaidUseCase(invoiceRepo, transactionRepo);
    registerFallbackValue(tTransactionDate);
    registerFallbackValue(tNow);
    registerFallbackValue(TransactionType.credit);
    registerFallbackValue(<String>[]);
  });

  group('MarkInvoicePaidUseCase', () {
    test('creates a credit transaction per line item and marks invoice paid',
        () async {
      // Arrange
      final tUnpaidInvoice =
          _makeInvoice(lineItems: [tLineItem1, tLineItem2]);
      final tPaidInvoice = _makeInvoice(
        paidAt: tNow,
        lineItems: [tLineItem1, tLineItem2],
      );

      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tUnpaidInvoice);
      when(() => transactionRepo.create(
            entityId: tEntityId,
            contactId: tContactId,
            generalLedgerId: tGlId1,
            amount: 5000,
            gstAmount: 500,
            transactionType: TransactionType.credit,
            receiptNumber: 'WMS-26-001',
            description: 'Annual membership',
            transactionDate: tTransactionDate,
          )).thenAnswer((_) async => _makeTx(tTxId1, tGlId1, 5000, 500));
      when(() => transactionRepo.create(
            entityId: tEntityId,
            contactId: tContactId,
            generalLedgerId: tGlId2,
            amount: 2000,
            gstAmount: 200,
            transactionType: TransactionType.credit,
            receiptNumber: 'WMS-26-001',
            description: 'Tool fee',
            transactionDate: tTransactionDate,
          )).thenAnswer((_) async => _makeTx(tTxId2, tGlId2, 2000, 200));
      when(() => transactionRepo.bankMatch(
            [tTxId1, tTxId2],
            entityId: tEntityId,
          )).thenAnswer((_) async {});
      when(() => invoiceRepo.markPaid(
            tInvoiceId,
            entityId: tEntityId,
            paidAt: any(named: 'paidAt'),
          )).thenAnswer((_) async => tPaidInvoice);

      // Act
      final result = await sut.execute(
        tInvoiceId,
        entityId: tEntityId,
        transactionDate: tTransactionDate,
      );

      // Assert
      expect(result.isPaid, isTrue);
      expect(result.paidAt, equals(tNow));
      verify(() => transactionRepo.create(
            entityId: tEntityId,
            contactId: tContactId,
            generalLedgerId: tGlId1,
            amount: 5000,
            gstAmount: 500,
            transactionType: TransactionType.credit,
            receiptNumber: 'WMS-26-001',
            description: 'Annual membership',
            transactionDate: tTransactionDate,
          )).called(1);
      verify(() => transactionRepo.create(
            entityId: tEntityId,
            contactId: tContactId,
            generalLedgerId: tGlId2,
            amount: 2000,
            gstAmount: 200,
            transactionType: TransactionType.credit,
            receiptNumber: 'WMS-26-001',
            description: 'Tool fee',
            transactionDate: tTransactionDate,
          )).called(1);
    });

    test('bank-matches all created transaction IDs', () async {
      // Arrange
      final tUnpaidInvoice =
          _makeInvoice(lineItems: [tLineItem1, tLineItem2]);
      final tPaidInvoice = _makeInvoice(paidAt: tNow);

      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tUnpaidInvoice);
      when(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: tGlId1,
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          )).thenAnswer((_) async => _makeTx(tTxId1, tGlId1, 5000, 500));
      when(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: tGlId2,
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          )).thenAnswer((_) async => _makeTx(tTxId2, tGlId2, 2000, 200));
      when(() => transactionRepo.bankMatch(any(), entityId: tEntityId))
          .thenAnswer((_) async {});
      when(() => invoiceRepo.markPaid(tInvoiceId,
              entityId: tEntityId, paidAt: any(named: 'paidAt')))
          .thenAnswer((_) async => tPaidInvoice);

      // Act
      await sut.execute(
        tInvoiceId,
        entityId: tEntityId,
        transactionDate: tTransactionDate,
      );

      // Assert — both transaction IDs must be bank-matched together
      verify(
        () => transactionRepo.bankMatch(
          [tTxId1, tTxId2],
          entityId: tEntityId,
        ),
      ).called(1);
    });

    test('uses receipt number from invoice on each created transaction',
        () async {
      // Arrange
      final tUnpaidInvoice = _makeInvoice(lineItems: [tLineItem1]);
      final tPaidInvoice = _makeInvoice(paidAt: tNow);

      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tUnpaidInvoice);
      when(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: 'WMS-26-001',
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          )).thenAnswer((_) async => _makeTx(tTxId1, tGlId1, 5000, 500));
      when(() => transactionRepo.bankMatch(any(), entityId: tEntityId))
          .thenAnswer((_) async {});
      when(() => invoiceRepo.markPaid(tInvoiceId,
              entityId: tEntityId, paidAt: any(named: 'paidAt')))
          .thenAnswer((_) async => tPaidInvoice);

      // Act
      await sut.execute(
        tInvoiceId,
        entityId: tEntityId,
        transactionDate: tTransactionDate,
      );

      // Assert — receipt number must equal the invoice number
      verify(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: 'WMS-26-001',
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          )).called(1);
    });

    test('creates only credit (money-in) transactions', () async {
      // Arrange
      final tUnpaidInvoice = _makeInvoice(lineItems: [tLineItem1]);
      final tPaidInvoice = _makeInvoice(paidAt: tNow);

      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tUnpaidInvoice);
      when(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: TransactionType.credit,
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          )).thenAnswer((_) async => _makeTx(tTxId1, tGlId1, 5000, 500));
      when(() => transactionRepo.bankMatch(any(), entityId: tEntityId))
          .thenAnswer((_) async {});
      when(() => invoiceRepo.markPaid(tInvoiceId,
              entityId: tEntityId, paidAt: any(named: 'paidAt')))
          .thenAnswer((_) async => tPaidInvoice);

      // Act
      await sut.execute(
        tInvoiceId,
        entityId: tEntityId,
        transactionDate: tTransactionDate,
      );

      // Assert — transaction type must be credit, never debit
      verify(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: TransactionType.credit,
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          )).called(1);
      verifyNever(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: TransactionType.debit,
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          ));
    });

    test('throws when invoice is not found', () async {
      // Arrange
      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      await expectLater(
        () => sut.execute(
          tInvoiceId,
          entityId: tEntityId,
          transactionDate: tTransactionDate,
        ),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('not found'))),
      );
      // No transaction or markPaid call should occur
      verifyNever(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          ));
      verifyNever(() => invoiceRepo.markPaid(
            any(),
            entityId: any(named: 'entityId'),
            paidAt: any(named: 'paidAt'),
          ));
    });

    test('throws when invoice is already paid', () async {
      // Arrange — invoice has a paidAt set
      final tPaidInvoice =
          _makeInvoice(paidAt: tNow, lineItems: [tLineItem1]);
      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tPaidInvoice);

      // Act / Assert
      await expectLater(
        () => sut.execute(
          tInvoiceId,
          entityId: tEntityId,
          transactionDate: tTransactionDate,
        ),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('already paid'))),
      );
      verifyNever(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          ));
    });

    test('throws when invoice has no line items', () async {
      // Arrange — invoice with empty lineItems
      final tEmptyInvoice = _makeInvoice(lineItems: []);
      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tEmptyInvoice);

      // Act / Assert
      await expectLater(
        () => sut.execute(
          tInvoiceId,
          entityId: tEntityId,
          transactionDate: tTransactionDate,
        ),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('no line items'))),
      );
      verifyNever(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          ));
    });

    test('falls back to invoice number as description when line item description is blank',
        () async {
      // Arrange
      final tItemNoDesc = InvoiceLineItem(
        id: '00000000-0000-0000-0000-000000000031',
        invoiceId: tInvoiceId,
        description: '',
        generalLedgerId: tGlId1,
        amountCents: 5000,
        gstCents: 500,
        createdAt: tNow,
      );
      final tUnpaidInvoice = _makeInvoice(lineItems: [tItemNoDesc]);
      final tPaidInvoice = _makeInvoice(paidAt: tNow);

      when(() => invoiceRepo.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tUnpaidInvoice);
      when(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: 'WMS-26-001',
            transactionDate: any(named: 'transactionDate'),
          )).thenAnswer((_) async => _makeTx(tTxId1, tGlId1, 5000, 500));
      when(() => transactionRepo.bankMatch(any(), entityId: tEntityId))
          .thenAnswer((_) async {});
      when(() => invoiceRepo.markPaid(tInvoiceId,
              entityId: tEntityId, paidAt: any(named: 'paidAt')))
          .thenAnswer((_) async => tPaidInvoice);

      // Act
      await sut.execute(
        tInvoiceId,
        entityId: tEntityId,
        transactionDate: tTransactionDate,
      );

      // Assert — description falls back to invoice number when blank
      verify(() => transactionRepo.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: 'WMS-26-001',
            transactionDate: any(named: 'transactionDate'),
          )).called(1);
    });
  });
}
