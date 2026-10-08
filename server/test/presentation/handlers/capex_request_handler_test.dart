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

import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/application/capex_request/create_capex_request_use_case.dart';
import 'package:shedbooks_server/application/capex_request/decide_capex_request_use_case.dart';
import 'package:shedbooks_server/application/capex_request/delete_capex_request_use_case.dart';
import 'package:shedbooks_server/application/capex_request/get_capex_request_use_case.dart';
import 'package:shedbooks_server/application/capex_request/get_next_capex_request_no_use_case.dart';
import 'package:shedbooks_server/application/capex_request/list_capex_requests_use_case.dart';
import 'package:shedbooks_server/application/capex_request/set_capex_request_executed_date_use_case.dart';
import 'package:shedbooks_server/application/capex_request/update_capex_request_use_case.dart';
import 'package:shedbooks_server/domain/entities/capex_request.dart';
import 'package:shedbooks_server/domain/entities/effective_permissions.dart';
import 'package:shedbooks_server/domain/enums/app_role.dart';
import 'package:shedbooks_server/domain/enums/capex_request_status.dart';
import 'package:shedbooks_server/domain/enums/permission_action.dart';
import 'package:shedbooks_server/domain/enums/permission_page.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_invoice_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_role_permission_repository.dart';
import 'package:shedbooks_server/presentation/handlers/capex_request_handler.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

class MockRolePermissionRepository extends Mock
    implements IRolePermissionRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late MockRolePermissionRepository permissions;
  late CapexRequestHandler sut;

  const String tEntityId = 'entity-1';
  const String tId = '00000000-0000-0000-0000-000000000001';
  final DateTime tDate = DateTime.utc(2026, 7, 1);

  final CapexRequest tApproved = CapexRequest(
    id: tId,
    entityId: tEntityId,
    requestNo: 'CER 26-012',
    requestDate: tDate,
    preparedByName: 'Rob Purves',
    description: 'Signs',
    whatIsRequested: 'Signs',
    needOrBenefit: 'Visibility',
    purchaseCostCents: 54450,
    totalAmountCents: 54450,
    status: CapexRequestStatus.approved,
    createdAt: tDate,
    updatedAt: tDate,
  );

  Request updateRequestAs(AppRole role) => Request(
        'PUT',
        Uri.parse('http://localhost/capex-requests/$tId'),
        body: jsonEncode({
          'requestNo': 'CER 26-012',
          'requestDate': '2026-07-01',
          'preparedByName': 'Rob Purves',
          'description': 'Signs (corrected)',
          'whatIsRequested': 'Signs',
          'needOrBenefit': 'Visibility',
          'purchaseCostCents': 54450,
          'totalAmountCents': 54450,
        }),
        context: {
          'auth.claims': {
            'https://shedbooks.com/entity_id': tEntityId,
            'https://shedbooks.com/roles': [role.name],
          },
        },
      );

  void stubEditDecidedPermission(AppRole role, {required bool granted}) {
    when(() => permissions.getEffective(entityId: tEntityId, role: role))
        .thenAnswer((_) async => EffectivePermissions(
              pages: const {
                PermissionPage.capexRequests: (canRead: true, canWrite: true),
              },
              actions: {PermissionAction.capexEditDecided: granted},
            ));
  }

  setUp(() {
    repository = MockCapexRequestRepository();
    permissions = MockRolePermissionRepository();
    final MockInvoiceRepository invoices = MockInvoiceRepository();
    registerFallbackValue(tDate);
    sut = CapexRequestHandler(
      create: CreateCapexRequestUseCase(repository, invoices),
      get: GetCapexRequestUseCase(repository),
      list: ListCapexRequestsUseCase(repository),
      update: UpdateCapexRequestUseCase(repository, invoices),
      delete: DeleteCapexRequestUseCase(repository),
      decide: DecideCapexRequestUseCase(repository),
      nextNumber: GetNextCapexRequestNoUseCase(repository),
      setExecutedDate: SetCapexRequestExecutedDateUseCase(repository),
      permissions: permissions,
    );

    when(() => repository.findById(tId, entityId: tEntityId))
        .thenAnswer((_) async => tApproved);
    when(() => repository.update(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
          requestNo: any(named: 'requestNo'),
          requestDate: any(named: 'requestDate'),
          preparedByName: any(named: 'preparedByName'),
          description: any(named: 'description'),
          whatIsRequested: any(named: 'whatIsRequested'),
          needOrBenefit: any(named: 'needOrBenefit'),
          alternativesConsidered: any(named: 'alternativesConsidered'),
          purchaseCostCents: any(named: 'purchaseCostCents'),
          ongoingCostsCents: any(named: 'ongoingCostsCents'),
          otherCostsCents: any(named: 'otherCostsCents'),
          costNotes: any(named: 'costNotes'),
          totalAmountCents: any(named: 'totalAmountCents'),
          quotesReceivedCount: any(named: 'quotesReceivedCount'),
          invoiceId: any(named: 'invoiceId'),
        )).thenAnswer((_) async => tApproved);
  });

  group('CapexRequestHandler.handleUpdate on a decided request', () {
    test('returns 400 when the role lacks capex-edit-decided', () async {
      // Arrange
      stubEditDecidedPermission(AppRole.contributor, granted: false);

      // Act
      final Response res =
          await sut.handleUpdate(updateRequestAs(AppRole.contributor), tId);

      // Assert
      expect(res.statusCode, equals(400));
      verifyNever(() => repository.update(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            requestNo: any(named: 'requestNo'),
            requestDate: any(named: 'requestDate'),
            preparedByName: any(named: 'preparedByName'),
            description: any(named: 'description'),
            whatIsRequested: any(named: 'whatIsRequested'),
            needOrBenefit: any(named: 'needOrBenefit'),
            alternativesConsidered: any(named: 'alternativesConsidered'),
            purchaseCostCents: any(named: 'purchaseCostCents'),
            ongoingCostsCents: any(named: 'ongoingCostsCents'),
            otherCostsCents: any(named: 'otherCostsCents'),
            costNotes: any(named: 'costNotes'),
            totalAmountCents: any(named: 'totalAmountCents'),
            quotesReceivedCount: any(named: 'quotesReceivedCount'),
            invoiceId: any(named: 'invoiceId'),
          ));
    });

    test('returns 200 when the role holds capex-edit-decided', () async {
      // Arrange
      stubEditDecidedPermission(AppRole.administrator, granted: true);

      // Act
      final Response res =
          await sut.handleUpdate(updateRequestAs(AppRole.administrator), tId);

      // Assert
      expect(res.statusCode, equals(200));
    });
  });
}
