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

import 'package:postgres/postgres.dart';

import '../../domain/entities/entity_details.dart';
import '../../domain/repositories/i_entity_details_repository.dart';
import '../encryption/field_encryptor.dart';

/// PostgreSQL implementation of [IEntityDetailsRepository].
class PostgresEntityDetailsRepository implements IEntityDetailsRepository {
  final Pool _pool;
  final FieldEncryptor _enc;

  const PostgresEntityDetailsRepository(this._pool, this._enc);

  /// @param entityId - Primary key used to look up the record.
  @override
  Future<EntityDetails?> find(String entityId) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT entity_id, name, abn, incorporation_identifier, apca_id,
               money_in_receipt_format, money_out_receipt_format,
               invoice_number_format, asset_no_format, created_at, updated_at
        FROM entity_details
        WHERE entity_id = @entityId
      '''),
      parameters: {'entityId': entityId},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  /// @param details.entityId - Upsert key.
  /// @param details.abn - Stored as CHAR(11); must be exactly 11 digits.
  @override
  Future<EntityDetails> save(EntityDetails details) async {
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO entity_details
          (entity_id, name, abn, incorporation_identifier, apca_id,
           money_in_receipt_format, money_out_receipt_format, invoice_number_format,
           asset_no_format)
        VALUES
          (@entityId, @name, @abn, @incorporationIdentifier, @apcaId,
           @moneyInReceiptFormat, @moneyOutReceiptFormat, @invoiceNumberFormat,
           @assetNoFormat)
        ON CONFLICT (entity_id) DO UPDATE
          SET name                     = EXCLUDED.name,
              abn                      = EXCLUDED.abn,
              incorporation_identifier = EXCLUDED.incorporation_identifier,
              apca_id                  = EXCLUDED.apca_id,
              money_in_receipt_format  = EXCLUDED.money_in_receipt_format,
              money_out_receipt_format = EXCLUDED.money_out_receipt_format,
              invoice_number_format    = EXCLUDED.invoice_number_format,
              asset_no_format          = EXCLUDED.asset_no_format,
              updated_at               = NOW()
        RETURNING entity_id, name, abn, incorporation_identifier, apca_id,
                  money_in_receipt_format, money_out_receipt_format,
                  invoice_number_format, asset_no_format, created_at, updated_at
      '''),
      parameters: {
        'entityId': details.entityId,
        'name': details.name,
        'abn': details.abn,
        'incorporationIdentifier': details.incorporationIdentifier,
        'apcaId': details.apcaId != null ? _enc.encrypt(details.apcaId!) : null,
        'moneyInReceiptFormat': details.moneyInReceiptFormat,
        'moneyOutReceiptFormat': details.moneyOutReceiptFormat,
        'invoiceNumberFormat': details.invoiceNumberFormat,
        'assetNoFormat': details.assetNoFormat,
      },
    );

    return _mapRow(result.first.toColumnMap());
  }

  EntityDetails _mapRow(Map<String, dynamic> row) => EntityDetails(
        entityId: row['entity_id'] as String,
        name: row['name'] as String,
        abn: (row['abn'] as String).trim(),
        incorporationIdentifier: row['incorporation_identifier'] as String,
        apcaId: row['apca_id'] != null
            ? _enc.decrypt(row['apca_id'] as String)
            : null,
        moneyInReceiptFormat: (row['money_in_receipt_format'] as String?) ?? '',
        moneyOutReceiptFormat: (row['money_out_receipt_format'] as String?) ?? '',
        invoiceNumberFormat: (row['invoice_number_format'] as String?) ?? 'WMS-YY-###',
        assetNoFormat: (row['asset_no_format'] as String?) ?? 'YYYY-{S}-####',
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );
}
