import '../../domain/entities/budget_gl_mapping.dart';
import '../../domain/entities/general_ledger.dart';
import '../../domain/repositories/i_budget_repository.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// A single parsed row from the import CSV, with a suggested GL match.
class ParsedImportRow {
  final String externalCode;
  final String externalName;
  final String? suggestedGlId;
  final String? suggestedGlLabel;

  /// 12-element list in cents; index 0 = January.
  final List<int> months;

  /// 0.0–1.0: 1.0 = exact saved mapping, lower = fuzzy name match.
  final double confidence;

  /// 'moneyIn' or 'moneyOut' — the CSV section this row belongs to.
  final String direction;

  const ParsedImportRow({
    required this.externalCode,
    required this.externalName,
    required this.suggestedGlId,
    required this.suggestedGlLabel,
    required this.months,
    required this.confidence,
    required this.direction,
  });
}

/// Parses a budget CSV and returns rows with GL match suggestions.
///
/// Supported format (the canonical format from the legacy system):
///   • Row 0: header — blank, then month columns ("Jan" or "2026 Jan"), then optional "Total"
///   • "Money In" / "Money Out" rows act as section headers; direction is inferred from the section
///   • Data rows: description in column 0, monthly dollar amounts in subsequent columns
///   • Rows whose description starts with "Total", "Net", "Opening Cash", or "Cash Balance" are skipped
///   • All-zero rows are skipped
///   • GL matching is restricted to accounts whose direction matches the current CSV section
///
/// Also supports a simpler format with an explicit Code and Name column if no section headers are present.
class ParseBudgetImportUseCase {
  final IBudgetRepository _budgetRepository;
  final IGeneralLedgerRepository _glRepository;

  const ParseBudgetImportUseCase(this._budgetRepository, this._glRepository);

  Future<List<ParsedImportRow>> execute({
    required String csvContent,
    required String entityId,
  }) async {
    final rawRows = _parseCsv(csvContent);
    if (rawRows.isEmpty) return [];

    final glAccounts = await _glRepository.findAll(entityId: entityId);
    final savedMappings = await _budgetRepository.getMappings(entityId: entityId);
    final mappingsByCode = {
      for (final BudgetGlMapping m in savedMappings) m.externalCode: m
    };

    final headerRow = rawRows.first.map((s) => s.trim().toLowerCase()).toList();
    final monthIndices = _findMonthIndices(headerRow);

    // Fall back to legacy Code/Name column format if no section headers are detected.
    final hasSections = rawRows
        .any((r) => _cell(r, 0).toLowerCase() == 'money in' || _cell(r, 0).toLowerCase() == 'money out');

    if (!hasSections) {
      return _parseLegacyFormat(rawRows, headerRow, monthIndices, glAccounts, mappingsByCode);
    }

    final results = <ParsedImportRow>[];
    String? currentSection; // 'moneyIn' or 'moneyOut'

    for (final row in rawRows.skip(1)) {
      final desc = _cell(row, 0).trim();
      if (desc.isEmpty) continue;

      final descLower = desc.toLowerCase();

      if (descLower == 'money in') { currentSection = 'moneyIn'; continue; }
      if (descLower == 'money out') { currentSection = 'moneyOut'; continue; }
      if (_isSkipRow(descLower)) continue;
      if (currentSection == null) continue;

      final months = _extractMonths(row, monthIndices);
      if (months.every((v) => v == 0)) continue;

      final glDirection = currentSection == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut;
      final relevantGl = glAccounts
          .where((g) => g.direction == glDirection && !g.isDeleted)
          .toList();

      // Use description as the matching key (no separate code column in this format).
      final savedMapping = mappingsByCode[desc];
      if (savedMapping != null) {
        final gl = _findGlById(relevantGl, savedMapping.generalLedgerId);
        if (gl != null) {
          results.add(ParsedImportRow(
            externalCode: desc,
            externalName: desc,
            suggestedGlId: gl.id,
            suggestedGlLabel: gl.description,
            months: months,
            confidence: 1.0,
            direction: currentSection,
          ));
          continue;
        }
      }

      final (glId, glLabel, confidence) = _fuzzyMatch(desc, relevantGl);
      results.add(ParsedImportRow(
        externalCode: desc,
        externalName: desc,
        suggestedGlId: glId,
        suggestedGlLabel: glLabel,
        months: months,
        confidence: confidence,
        direction: currentSection,
      ));
    }

    return results;
  }

  // ── Legacy Code/Name format ────────────────────────────────────────────────

  List<ParsedImportRow> _parseLegacyFormat(
    List<List<String>> rawRows,
    List<String> headers,
    Map<int, int> monthIndices,
    List<GeneralLedger> glAccounts,
    Map<String, BudgetGlMapping> mappingsByCode,
  ) {
    final dataRows = rawRows.skip(1).where((r) => r.isNotEmpty).toList();
    return dataRows.map((row) {
      final code = _cell(row, 0);
      final name = _cell(row, 1);
      final months = monthIndices.isNotEmpty
          ? _extractMonths(row, monthIndices)
          : _spreadAnnual(row);

      final savedMapping = mappingsByCode[code];
      if (savedMapping != null) {
        final gl = _findGlById(glAccounts.where((g) => !g.isDeleted).toList(),
            savedMapping.generalLedgerId);
        if (gl != null) {
          return ParsedImportRow(
            externalCode: code,
            externalName: name,
            suggestedGlId: gl.id,
            suggestedGlLabel: gl.description,
            months: months,
            confidence: 1.0,
            direction: gl.direction == GlDirection.moneyIn ? 'moneyIn' : 'moneyOut',
          );
        }
      }

      final activeGl = glAccounts.where((g) => !g.isDeleted).toList();
      final (glId, glLabel, confidence) = _fuzzyMatch(name.isNotEmpty ? name : code, activeGl);
      final matchedGl = glId != null ? _findGlById(activeGl, glId) : null;
      return ParsedImportRow(
        externalCode: code,
        externalName: name,
        suggestedGlId: glId,
        suggestedGlLabel: glLabel,
        months: months,
        confidence: confidence,
        direction: matchedGl?.direction == GlDirection.moneyIn ? 'moneyIn' : 'moneyOut',
      );
    }).toList();
  }

  // ── CSV parsing ────────────────────────────────────────────────────────────

  static List<List<String>> _parseCsv(String content) {
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map(_parseLine)
        .toList();
  }

  static List<String> _parseLine(String line) {
    final fields = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    fields.add(buf.toString().trim());
    return fields;
  }

  // ── Month detection ────────────────────────────────────────────────────────

  static const _monthAbbreviations = {
    'jan': 0, 'feb': 1, 'mar': 2, 'apr': 3, 'may': 4, 'jun': 5,
    'jul': 6, 'aug': 7, 'sep': 8, 'sept': 8, 'oct': 9, 'nov': 10, 'dec': 11,
    'january': 0, 'february': 1, 'march': 2, 'april': 3, 'june': 5,
    'july': 6, 'august': 7, 'september': 8, 'october': 9,
    'november': 10, 'december': 11,
  };

  /// Scans [headers] and returns a map of monthIndex (0–11) → column index.
  /// Handles both plain ("Jan") and year-prefixed ("2026 Jan") headers.
  static Map<int, int> _findMonthIndices(List<String> headers) {
    final result = <int, int>{};
    for (int col = 0; col < headers.length; col++) {
      final parts = headers[col].trim().split(RegExp(r'\s+'));
      final monthToken = parts.last; // "2026 jan" → "jan"; "jan" → "jan"
      final monthIdx = _monthAbbreviations[monthToken];
      if (monthIdx != null && !result.containsKey(monthIdx)) {
        result[monthIdx] = col;
      }
    }
    return result;
  }

  /// Reads column 2 as an annual total and spreads it evenly across 12 months.
  static List<int> _spreadAnnual(List<String> row) {
    final annual = _parseCents(_cell(row, 2));
    final perMonth = annual ~/ 12;
    final remainder = annual - perMonth * 12;
    final months = List<int>.filled(12, perMonth);
    if (remainder > 0) months[0] += remainder;
    return months;
  }

  static List<int> _extractMonths(List<String> row, Map<int, int> monthIndices) {
    final result = List<int>.filled(12, 0);
    for (final entry in monthIndices.entries) {
      final colIdx = entry.value;
      if (colIdx < row.length) {
        result[entry.key] = _parseCents(row[colIdx]);
      }
    }
    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _cell(List<String> row, int idx) =>
      idx < row.length ? row[idx].trim() : '';

  /// Converts a dollar string to cents. Values are assumed to be whole dollars.
  static int _parseCents(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\$,\s]'), '');
    if (cleaned.isEmpty) return 0;
    final value = double.tryParse(cleaned) ?? 0.0;
    return (value * 100).round().abs();
  }

  static bool _isSkipRow(String descLower) =>
      descLower.startsWith('total') ||
      descLower == 'net' ||
      descLower.startsWith('opening cash') ||
      descLower.startsWith('closing cash') ||
      descLower.startsWith('cash balance');

  static GeneralLedger? _findGlById(List<GeneralLedger> accounts, String id) {
    try {
      return accounts.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns (glId, glLabel, confidence) for the closest matching GL account.
  ///
  /// CSV candidates are built from [name] in priority order:
  ///   [0] leaf segment  — "Recycling"              (most specific, wins ties)
  ///   [1] full string   — "Fundraising - Recycling"
  ///   [2+] parent segs  — "Fundraising"
  ///
  /// Each candidate is scored against two GL-side targets per account:
  ///   • gl.description  — the leaf name ("Recycling")
  ///   • full path       — parent chain joined with " > " ("Fundraising > Recycling")
  ///
  /// This lets a flat CSV description like "Fundraising - Recycling" match
  /// "Fundraising > Recycling" (the GL path) with high bigram similarity even
  /// when the leaf description alone is ambiguous.
  static (String?, String?, double) _fuzzyMatch(
    String name,
    List<GeneralLedger> accounts,
  ) {
    if (name.isEmpty || accounts.isEmpty) return (null, null, 0.0);

    // Build an id→account map so _glPath can walk parent chains.
    final byId = <String, GeneralLedger>{for (final g in accounts) g.id: g};

    // Build candidate list in priority order (leaf first, wins ties).
    final segments = name.split(RegExp(r'\s[-–/]\s'));
    final raw = <String>[];
    if (segments.length > 1) raw.add(segments.last.trim().toLowerCase());
    raw.add(name.toLowerCase());
    for (int i = segments.length - 2; i >= 0; i--) {
      final t = segments[i].trim();
      if (t.isNotEmpty) raw.add(t.toLowerCase());
    }
    final seen = <String>{};
    final candidates = raw.where(seen.add).toList();

    String? bestId;
    String? bestLabel;
    double bestScore = 0.0;
    int bestRank = candidates.length;

    for (final gl in accounts) {
      // Score each candidate against both the leaf description and the full path.
      final targets = <String>{
        gl.description.toLowerCase(),
        _glPath(gl, byId).toLowerCase(),
      };

      for (int rank = 0; rank < candidates.length; rank++) {
        double s = 0.0;
        for (final target in targets) {
          final ts = _similarity(candidates[rank], target);
          if (ts > s) s = ts;
        }
        if (s > bestScore || (s == bestScore && rank < bestRank)) {
          bestScore = s;
          bestRank = rank;
          bestId = gl.id;
          bestLabel = gl.description;
        }
      }
    }

    if (bestScore < 0.3) return (null, null, 0.0);
    return (bestId, bestLabel, bestScore);
  }

  /// Builds the full display path for [gl] by walking its parent chain.
  /// Returns "Fundraising > Recycling" for a child account.
  static String _glPath(GeneralLedger gl, Map<String, GeneralLedger> byId) {
    final parts = <String>[];
    GeneralLedger? current = gl;
    while (current != null) {
      parts.insert(0, current.description);
      current = current.parentId != null ? byId[current.parentId!] : null;
    }
    return parts.join(' > ');
  }

  /// Dice coefficient bigram similarity between two strings.
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;

    Set<String> bigrams(String s) {
      final set = <String>{};
      for (int i = 0; i < s.length - 1; i++) {
        set.add(s.substring(i, i + 2));
      }
      return set;
    }

    final ba = bigrams(a);
    final bb = bigrams(b);
    final intersection = ba.intersection(bb).length;
    return (2.0 * intersection) / (ba.length + bb.length);
  }
}
