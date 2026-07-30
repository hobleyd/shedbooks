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

import 'package:flutter/foundation.dart';

import '../models/bank_account_entry.dart';
import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/gst_rate_entry.dart';
import '../models/locked_month_entry.dart';
import 'api_client.dart';

/// Load state of a single cached resource.
enum LoadStatus { idle, loading, loaded, error }

/// Shared cache of reference data (contacts, GL accounts, bank accounts,
/// GST rates, entity details, locked months) fetched lazily and shared
/// across every screen via [ChangeNotifier].
///
/// Screens read the cached lists via `context.watch`/`context.read` instead
/// of fetching their own copy, so a write on one screen (e.g. adding a
/// contact) can call the matching `refreshX()` and every other screen
/// holding that data — including screens retained off-screen by
/// `StatefulShellRoute.indexedStack` — rebuilds immediately.
class ReferenceDataCache extends ChangeNotifier {
  final ApiClient _apiClient;

  ReferenceDataCache(this._apiClient);

  /// Bumped by [reset]; a load whose epoch no longer matches on completion
  /// discards its result instead of writing stale/cross-tenant data into
  /// the cache after logout.
  int _epoch = 0;

  LoadStatus _contactsStatus = LoadStatus.idle;
  List<ContactEntry> _contacts = [];
  String? _contactsError;
  int _contactsGen = 0;

  LoadStatus _glStatus = LoadStatus.idle;
  List<GeneralLedgerEntry> _glEntries = [];
  String? _glError;
  int _glGen = 0;

  LoadStatus _bankAccountsStatus = LoadStatus.idle;
  List<BankAccountEntry> _bankAccounts = [];
  String? _bankAccountsError;
  int _bankAccountsGen = 0;

  LoadStatus _gstRatesStatus = LoadStatus.idle;
  List<GstRateEntry> _gstRates = [];
  String? _gstRatesError;
  int _gstRatesGen = 0;

  LoadStatus _entityDetailsStatus = LoadStatus.idle;
  EntityDetails? _entityDetails;
  String? _entityDetailsError;
  int _entityDetailsGen = 0;

  LoadStatus _lockedMonthsStatus = LoadStatus.idle;
  List<LockedMonthEntry> _lockedMonths = [];
  String? _lockedMonthsError;
  int _lockedMonthsGen = 0;

  LoadStatus get contactsStatus => _contactsStatus;
  List<ContactEntry> get contacts => List.unmodifiable(_contacts);
  String? get contactsError => _contactsError;

  LoadStatus get glStatus => _glStatus;
  List<GeneralLedgerEntry> get glEntries => List.unmodifiable(_glEntries);
  String? get glError => _glError;

  LoadStatus get bankAccountsStatus => _bankAccountsStatus;
  List<BankAccountEntry> get bankAccounts => List.unmodifiable(_bankAccounts);
  String? get bankAccountsError => _bankAccountsError;

  LoadStatus get gstRatesStatus => _gstRatesStatus;
  List<GstRateEntry> get gstRates => List.unmodifiable(_gstRates);
  String? get gstRatesError => _gstRatesError;

  LoadStatus get entityDetailsStatus => _entityDetailsStatus;
  EntityDetails? get entityDetails => _entityDetails;
  String? get entityDetailsError => _entityDetailsError;

  LoadStatus get lockedMonthsStatus => _lockedMonthsStatus;
  List<LockedMonthEntry> get lockedMonths => List.unmodifiable(_lockedMonths);
  String? get lockedMonthsError => _lockedMonthsError;

  /// The GST rate effective at [date] (defaults to now): the rate with the
  /// latest `effectiveFrom` that is not after [date]. Mirrors the server's
  /// `GetEffectiveGstRateUseCase` (`effective_from <= date ORDER BY
  /// effective_from DESC LIMIT 1`), computed client-side over the cached
  /// list so callers don't need the separate `/gst-rates/effective` fetch.
  GstRateEntry? effectiveGstRate([DateTime? date]) {
    final target = date ?? DateTime.now();
    final candidates =
        _gstRates.where((r) => !r.effectiveFrom.isAfter(target)).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return candidates.first;
  }

  Future<void> ensureContactsLoaded() => _isLoadedOrLoading(_contactsStatus)
      ? Future.value()
      : _loadContacts();
  Future<void> refreshContacts() => _loadContacts();

  Future<void> ensureGlLoaded() =>
      _isLoadedOrLoading(_glStatus) ? Future.value() : _loadGl();
  Future<void> refreshGl() => _loadGl();

  Future<void> ensureBankAccountsLoaded() =>
      _isLoadedOrLoading(_bankAccountsStatus)
          ? Future.value()
          : _loadBankAccounts();
  Future<void> refreshBankAccounts() => _loadBankAccounts();

  Future<void> ensureGstRatesLoaded() => _isLoadedOrLoading(_gstRatesStatus)
      ? Future.value()
      : _loadGstRates();
  Future<void> refreshGstRates() => _loadGstRates();

  Future<void> ensureEntityDetailsLoaded() =>
      _isLoadedOrLoading(_entityDetailsStatus)
          ? Future.value()
          : _loadEntityDetails();
  Future<void> refreshEntityDetails() => _loadEntityDetails();

  Future<void> ensureLockedMonthsLoaded() =>
      _isLoadedOrLoading(_lockedMonthsStatus)
          ? Future.value()
          : _loadLockedMonths();
  Future<void> refreshLockedMonths() => _loadLockedMonths();

  bool _isLoadedOrLoading(LoadStatus status) =>
      status == LoadStatus.loaded || status == LoadStatus.loading;

  Future<void> _loadContacts() async {
    final epoch = _epoch;
    final gen = ++_contactsGen;
    _contactsStatus = LoadStatus.loading;
    try {
      final res = await _apiClient.get('/contacts');
      if (epoch != _epoch || gen != _contactsGen) return;
      if (res.statusCode != 200) {
        _contactsStatus = LoadStatus.error;
        _contactsError = 'Failed to load contacts (${res.statusCode})';
      } else {
        _contacts = (jsonDecode(res.body) as List)
            .map((e) => ContactEntry.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _contactsStatus = LoadStatus.loaded;
        _contactsError = null;
      }
    } catch (e) {
      if (epoch != _epoch || gen != _contactsGen) return;
      _contactsStatus = LoadStatus.error;
      _contactsError = 'Failed to load contacts: $e';
    }
    notifyListeners();
  }

  Future<void> _loadGl() async {
    final epoch = _epoch;
    final gen = ++_glGen;
    _glStatus = LoadStatus.loading;
    try {
      final res = await _apiClient.get('/general-ledger');
      if (epoch != _epoch || gen != _glGen) return;
      if (res.statusCode != 200) {
        _glStatus = LoadStatus.error;
        _glError = 'Failed to load general ledger accounts (${res.statusCode})';
      } else {
        _glEntries = (jsonDecode(res.body) as List)
            .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.description.compareTo(b.description));
        _glStatus = LoadStatus.loaded;
        _glError = null;
      }
    } catch (e) {
      if (epoch != _epoch || gen != _glGen) return;
      _glStatus = LoadStatus.error;
      _glError = 'Failed to load general ledger accounts: $e';
    }
    notifyListeners();
  }

  Future<void> _loadBankAccounts() async {
    final epoch = _epoch;
    final gen = ++_bankAccountsGen;
    _bankAccountsStatus = LoadStatus.loading;
    try {
      final res = await _apiClient.get('/bank-accounts');
      if (epoch != _epoch || gen != _bankAccountsGen) return;
      if (res.statusCode != 200) {
        _bankAccountsStatus = LoadStatus.error;
        _bankAccountsError = 'Failed to load bank accounts (${res.statusCode})';
      } else {
        _bankAccounts = (jsonDecode(res.body) as List)
            .map((e) => BankAccountEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _bankAccountsStatus = LoadStatus.loaded;
        _bankAccountsError = null;
      }
    } catch (e) {
      if (epoch != _epoch || gen != _bankAccountsGen) return;
      _bankAccountsStatus = LoadStatus.error;
      _bankAccountsError = 'Failed to load bank accounts: $e';
    }
    notifyListeners();
  }

  Future<void> _loadGstRates() async {
    final epoch = _epoch;
    final gen = ++_gstRatesGen;
    _gstRatesStatus = LoadStatus.loading;
    try {
      final res = await _apiClient.get('/gst-rates');
      if (epoch != _epoch || gen != _gstRatesGen) return;
      if (res.statusCode != 200) {
        _gstRatesStatus = LoadStatus.error;
        _gstRatesError = 'Failed to load GST rates (${res.statusCode})';
      } else {
        _gstRates = (jsonDecode(res.body) as List)
            .map((e) => GstRateEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _gstRatesStatus = LoadStatus.loaded;
        _gstRatesError = null;
      }
    } catch (e) {
      if (epoch != _epoch || gen != _gstRatesGen) return;
      _gstRatesStatus = LoadStatus.error;
      _gstRatesError = 'Failed to load GST rates: $e';
    }
    notifyListeners();
  }

  Future<void> _loadEntityDetails() async {
    final epoch = _epoch;
    final gen = ++_entityDetailsGen;
    _entityDetailsStatus = LoadStatus.loading;
    try {
      final res = await _apiClient.get('/entity-details');
      if (epoch != _epoch || gen != _entityDetailsGen) return;
      if (res.statusCode != 200) {
        _entityDetailsStatus = LoadStatus.error;
        _entityDetailsError = 'Failed to load entity details (${res.statusCode})';
      } else {
        _entityDetails =
            EntityDetails.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        _entityDetailsStatus = LoadStatus.loaded;
        _entityDetailsError = null;
      }
    } catch (e) {
      if (epoch != _epoch || gen != _entityDetailsGen) return;
      _entityDetailsStatus = LoadStatus.error;
      _entityDetailsError = 'Failed to load entity details: $e';
    }
    notifyListeners();
  }

  Future<void> _loadLockedMonths() async {
    final epoch = _epoch;
    final gen = ++_lockedMonthsGen;
    _lockedMonthsStatus = LoadStatus.loading;
    try {
      final res = await _apiClient.get('/locked-months');
      if (epoch != _epoch || gen != _lockedMonthsGen) return;
      if (res.statusCode != 200) {
        _lockedMonthsStatus = LoadStatus.error;
        _lockedMonthsError = 'Failed to load locked months (${res.statusCode})';
      } else {
        _lockedMonths = (jsonDecode(res.body) as List)
            .map((e) => LockedMonthEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _lockedMonthsStatus = LoadStatus.loaded;
        _lockedMonthsError = null;
      }
    } catch (e) {
      if (epoch != _epoch || gen != _lockedMonthsGen) return;
      _lockedMonthsStatus = LoadStatus.error;
      _lockedMonthsError = 'Failed to load locked months: $e';
    }
    notifyListeners();
  }

  /// Clears every cached resource back to [LoadStatus.idle] and bumps the
  /// epoch so any in-flight load from a previous session (e.g. one still
  /// awaiting its GET at logout) cannot write stale or cross-tenant data
  /// into the cache once it resolves.
  void reset() {
    _epoch++;
    _contactsStatus = LoadStatus.idle;
    _contacts = [];
    _contactsError = null;
    _glStatus = LoadStatus.idle;
    _glEntries = [];
    _glError = null;
    _bankAccountsStatus = LoadStatus.idle;
    _bankAccounts = [];
    _bankAccountsError = null;
    _gstRatesStatus = LoadStatus.idle;
    _gstRates = [];
    _gstRatesError = null;
    _entityDetailsStatus = LoadStatus.idle;
    _entityDetails = null;
    _entityDetailsError = null;
    _lockedMonthsStatus = LoadStatus.idle;
    _lockedMonths = [];
    _lockedMonthsError = null;
    notifyListeners();
  }
}
