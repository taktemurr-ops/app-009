import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';
import 'money.dart';

abstract class Vault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class DeviceVault implements Vault {
  static const _key = 'budget360_data_v1';
  const DeviceVault();
  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryVault implements Vault {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('Simulated write failure');
    this.value = value;
  }
  @override
  Future<void> clear() async {
    if (failWrite) throw StateError('Simulated delete failure');
    value = null;
  }
}

/// All mutations are serialized and persisted before UI state changes.
/// A failed encrypted-storage write does not leave a phantom in-memory record.
class BudgetRepository extends ChangeNotifier {
  final Vault vault;
  BudgetData _data = const BudgetData();
  bool _loaded = false;
  String? _loadError;
  Future<void> _lastMutation = Future<void>.value();
  final Random _random = Random.secure();
  BudgetRepository(this.vault);

  BudgetData get data => _data;
  bool get loaded => _loaded;
  String? get loadError => _loadError;

  String nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';

  Future<void> load() async {
    String? raw;
    try {
      raw = await vault.read();
    } catch (_) {
      _loadError = 'Encrypted storage is unavailable. No stored data was overwritten.';
      _loaded = true;
      notifyListeners();
      return;
    }
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException('Invalid vault root');
        _data = BudgetData.fromJson(Map<String, dynamic>.from(decoded));
        _loadError = null;
      } catch (_) {
        // Keep corrupt bytes available for recovery. Never overwrite on load.
        _loadError = 'Stored data could not be decoded. Export it for recovery before resetting.';
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _change(BudgetData Function(BudgetData) update) {
    final completer = _lastMutation.then((_) async {
      if (_loadError != null) throw StateError(_loadError);
      final next = update(_data);
      final json = jsonEncode(next.toJson());
      await vault.write(json);
      _data = next;
      notifyListeners();
    });
    _lastMutation = completer.catchError((Object _) {});
    return completer;
  }

  Future<void> record({required int cents, required String kind,
    required String category, String note = '', DateTime? date}) {
    if (cents <= 0 || !['expense', 'income'].contains(kind) ||
        category.trim().isEmpty || category.length > 180 || note.length > 1000) {
      throw ArgumentError('Invalid transaction');
    }
    return _change((d) => d.copyWith(entries: [
      MoneyEntry(id: nextId(), occurredAt: date ?? DateTime.now(), cents: cents,
        kind: kind, category: category, note: note, member: d.member),
      ...d.entries,
    ]));
  }

  Future<void> removeEntry(String id) => _change((d) =>
    d.copyWith(entries: d.entries.where((e) => e.id != id).toList()));

  Future<void> setBudget(String category, int cents) {
    if (category.trim().isEmpty || category.length > 180 || cents <= 0) throw ArgumentError('Invalid budget');
    return _change((d) => d.copyWith(budgets: [
      ...d.budgets.where((b) => b.category != category),
      CategoryBudget(category, cents),
    ]));
  }

  Future<void> removeBudget(String category) => _change((d) =>
    d.copyWith(budgets: d.budgets.where((e) => e.category != category).toList()));

  /// Apply the 50/30/20 starter template in one encrypted transaction.
  Future<void> applyStarterTemplate(int monthlyIncomeCents) {
    if (monthlyIncomeCents < 100) throw ArgumentError('Income too small for template');
    final essential = (monthlyIncomeCents * 50) ~/ 100;
    final lifestyle = (monthlyIncomeCents * 30) ~/ 100;
    final savings = monthlyIncomeCents - essential - lifestyle;
    return _change((d) => d.copyWith(budgets: [
      ...d.budgets.where((b) => !['Housing', 'Shopping', 'Savings'].contains(b.category)),
      CategoryBudget('Housing', essential), CategoryBudget('Shopping', lifestyle),
      CategoryBudget('Savings', savings),
    ]));
  }

  Future<void> addGoal(String title, int target) {
    if (title.trim().isEmpty || title.length > 180 || target <= 0) throw ArgumentError('Invalid goal');
    return _change((d) => d.copyWith(goals: [
      ...d.goals, SavingsGoal(id: nextId(), title: title.trim(), targetCents: target, savedCents: 0),
    ]));
  }

  Future<void> contribute(String id, int cents) {
    if (cents <= 0) throw ArgumentError('Invalid contribution');
    return _change((d) {
      if (!d.goals.any((g) => g.id == id)) throw ArgumentError('Goal not found');
      return d.copyWith(goals: d.goals.map((g) {
        if (g.id != id) return g;
        if (g.savedCents + cents > g.targetCents) throw ArgumentError('Overfunded goal');
        return SavingsGoal(id: g.id, title: g.title, targetCents: g.targetCents,
          savedCents: g.savedCents + cents);
      }).toList());
    });
  }

  Future<void> removeGoal(String id) => _change((d) =>
    d.copyWith(goals: d.goals.where((g) => g.id != id).toList()));

  Future<void> addRecurring({required String title, required int cents,
    required String category, required String kind, required int day}) {
    if (title.trim().isEmpty || title.length > 180 || cents <= 0 ||
        category.trim().isEmpty || category.length > 180 ||
        !['expense', 'income'].contains(kind) || day < 1 || day > 31) {
      throw ArgumentError('Invalid recurring entry');
    }
    return _change((d) => d.copyWith(recurring: [
      ...d.recurring, RecurringRule(id: nextId(), title: title.trim(),
        cents: cents, category: category, kind: kind, day: day),
    ]));
  }

  Future<void> removeRecurring(String id) => _change((d) =>
    d.copyWith(recurring: d.recurring.where((r) => r.id != id).toList()));

  /// Applies the current month's due payments exactly once per rule.
  /// A rule scheduled on day 31 falls on the last day in shorter months.
  /// These are *recorded entries*, not external bank transfers.
  Future<int> applyDue(DateTime now) async {
    var count = 0;
    await _change((d) {
      final additions = <MoneyEntry>[];
      final key = monthKey(now);
      for (final rule in d.recurring.where((r) => r.enabled)) {
        final day = min(rule.day, lastDayOfMonth(now.year, now.month));
        if (now.day < day) continue;
        final deterministicId = 'rec:${rule.id}:$key';
        if (d.entries.any((e) => e.id == deterministicId)) continue;
        additions.add(MoneyEntry(id: deterministicId,
          occurredAt: DateTime(now.year, now.month, day), cents: rule.cents,
          kind: rule.kind, category: rule.category, note: rule.title,
          member: d.member, recurringId: rule.id));
      }
      count = additions.length;
      return d.copyWith(entries: [...additions, ...d.entries]);
    });
    return count;
  }

  Future<void> addChecklist(String title) {
    if (title.trim().isEmpty || title.length > 180) throw ArgumentError('Invalid task');
    return _change((d) => d.copyWith(checklist: [
      ...d.checklist, ChecklistItem(id: nextId(), title: title.trim()),
    ]));
  }

  Future<void> toggleChecklist(String id) => _change((d) => d.copyWith(checklist:
    d.checklist.map((e) => e.id == id ? ChecklistItem(id: e.id,
      title: e.title, done: !e.done) : e).toList()));

  Future<void> removeChecklist(String id) => _change((d) => d.copyWith(checklist:
    d.checklist.where((e) => e.id != id).toList()));

  Future<void> addJournal(String note) {
    if (note.trim().isEmpty || note.length > 1000) throw ArgumentError('Invalid note');
    return _change((d) => d.copyWith(journal: [
      JournalNote(nextId(), DateTime.now(), note.trim()), ...d.journal,
    ]));
  }

  Future<void> removeJournal(String id) => _change((d) => d.copyWith(journal:
    d.journal.where((e) => e.id != id).toList()));

  Future<void> addMember(String name) {
    if (name.trim().isEmpty || name.length > 180) throw ArgumentError('Invalid member');
    return _change((d) {
      final clean = name.trim();
      if (d.members.contains(clean) || d.members.length >= 20) throw ArgumentError('Member already exists / limit');
      return d.copyWith(members: [...d.members, clean]);
    });
  }

  Future<void> setMember(String name) => _change((d) {
    if (!d.members.contains(name)) throw ArgumentError('Unknown member');
    return d.copyWith(member: name);
  });

  Future<void> setCurrency(String code) => _change((d) {
    if (!supportedCurrencies.contains(code)) throw ArgumentError('Unknown currency');
    if (d.entries.isNotEmpty || d.budgets.isNotEmpty || d.goals.isNotEmpty || d.recurring.isNotEmpty) {
      throw StateError('Currency cannot change after records exist (no FX conversion).');
    }
    return d.copyWith(currency: code);
  });

  Future<void> setLocale(String code) => _change((d) {
    if (!['tr', 'en', 'ar'].contains(code)) throw ArgumentError('Unsupported language');
    return d.copyWith(locale: code);
  });

  /// An explicit, unencrypted portable backup; user must copy it deliberately.
  String exportJson() => jsonEncode({
    'format': 'butce360', 'schema': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(), 'data': _data.toJson(),
  });

  /// Validates all imported records before replacing encrypted persistent data.
  /// The caller must require explicit user confirmation before invoking.
  Future<void> importJson(String raw) {
    if (raw.length > 10 * 1024 * 1024) throw const FormatException('Backup too large');
    final payload = jsonDecode(raw);
    if (payload is! Map || payload['format'] != 'butce360' || payload['schema'] != 1) {
      throw const FormatException('Invalid backup format');
    }
    final restored = BudgetData.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
    return _change((_) => restored);
  }

  Future<void> clearAll() async {
    final task = _lastMutation.then((_) async {
      await vault.clear();
      _data = const BudgetData();
      _loadError = null;
      notifyListeners();
    });
    _lastMutation = task.catchError((Object _) {});
    await task;
  }
}
