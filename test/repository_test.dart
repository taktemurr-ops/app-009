import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:butce_360/core/insights.dart';
import 'package:butce_360/core/models.dart';
import 'package:butce_360/core/repository.dart';

void main() {
  late MemoryVault vault;
  late BudgetRepository repo;
  setUp(() async {
    vault = MemoryVault();
    repo = BudgetRepository(vault);
    await repo.load();
  });
  tearDown(() => repo.dispose());

  test('transactions persist in cents with financial reporting', () async {
    await repo.record(cents: 200000, kind: 'income', category: 'Other', date: DateTime(2026, 11, 2));
    await repo.record(cents: 4575, kind: 'expense', category: 'Food', date: DateTime(2026, 11, 3));
    final summary = summarize(repo.data, DateTime(2026, 11));
    expect(summary.income, 200000);
    expect(summary.expense, 4575);
    expect(summary.balance, 195425);
    expect(expenseBreakdown(repo.data, DateTime(2026,11))['Food'], 4575);
    final restored = BudgetRepository(vault);
    await restored.load();
    expect(restored.data.entries.length, 2);
    expect(restored.data.entries.last.cents, 200000);
    restored.dispose();
  });

  test('failed vault writes cannot change active journal state', () async {
    vault.failWrite = true;
    await expectLater(repo.record(cents: 100, kind: 'expense', category: 'Food'), throwsStateError);
    expect(repo.data.entries, isEmpty);
    expect(vault.value, isNull);
    vault.failWrite = false;
    await repo.record(cents: 400, kind: 'expense', category: 'Food');
    expect(repo.data.entries.single.cents, 400);
  });

  test('monthly budget shows spending and updates safely', () async {
    await repo.setBudget('Food', 50000);
    await repo.record(cents: 8000, kind: 'expense', category: 'Food', date: DateTime(2026,11,1));
    await repo.record(cents: 1000, kind: 'expense', category: 'Food', date: DateTime(2026,10,1));
    expect(spentInCategory(repo.data, DateTime(2026,11), 'Food'), 8000);
    await repo.setBudget('Food', 60000);
    expect(repo.data.budgets.length, 1);
    expect(repo.data.budgets.single.cents, 60000);
    await repo.removeBudget('Food');
    expect(repo.data.budgets, isEmpty);
  });

  test('recurring entries are applied once in short months', () async {
    await repo.addRecurring(title: 'Rent', cents: 40000,
      category: 'Housing', kind: 'expense', day: 31);
    expect(await repo.applyDue(DateTime(2026, 2, 27)), 0);
    expect(await repo.applyDue(DateTime(2026, 2, 28)), 1);
    expect(await repo.applyDue(DateTime(2026, 2, 28)), 0);
    expect(repo.data.entries.single.occurredAt.day, 28);
    expect(await repo.applyDue(DateTime(2026, 3, 30)), 0);
    expect(await repo.applyDue(DateTime(2026, 3, 31)), 1);
    expect(repo.data.entries.length, 2);
    expect(projectedMonthlyExpenses(repo.data), 40000);
  });

  test('goal contributions do not double-count expenses', () async {
    await repo.addGoal('Laptop', 100000);
    final id = repo.data.goals.single.id;
    await repo.contribute(id, 15000);
    expect(repo.data.goals.single.savedCents, 15000);
    await expectLater(repo.contribute(id, 90000), throwsArgumentError);
    expect(repo.data.goals.single.savedCents, 15000);
    expect(repo.data.entries, isEmpty);
  });

  test('template applies atomically without affecting other budgets', () async {
    await repo.setBudget('Bills', 20000);
    await repo.applyStarterTemplate(100000);
    expect(repo.data.budgets.first.cents, 20000);
    expect(repo.data.budgets.length, 4);
    expect(repo.data.budgets.last.cents, 20000);
    vault.failWrite = true;
    await expectLater(repo.applyStarterTemplate(200000), throwsStateError);
    expect(repo.data.budgets[1].cents, 50000);
  });

  test('household member names are local labels on entries', () async {
    await repo.addMember('Ada');
    await repo.setMember('Ada');
    await repo.record(cents: 501, kind: 'expense', category: 'Education');
    expect(repo.data.entries.single.member, 'Ada');
    expect(repo.data.member, 'Ada');
  });

  test('backup import validates and restores all data', () async {
    await repo.addChecklist('Pay insurance');
    await repo.toggleChecklist(repo.data.checklist.single.id);
    await repo.addJournal('Save for repairs');
    await repo.setLocale('ar');
    final backup = repo.exportJson();
    expect(jsonDecode(backup)['schema'], 1);
    await repo.clearAll();
    expect(repo.data.checklist, isEmpty);
    await repo.importJson(backup);
    expect(repo.data.locale, 'ar');
    expect(repo.data.checklist.single.done, isTrue);
    expect(repo.data.journal.single.text, 'Save for repairs');
  });

  test('invalid backup does not destroy existing encrypted records', () async {
    await repo.record(cents: 199, kind: 'expense', category: 'Food');
    final before = vault.value;
    await expectLater(repo.importJson('{"format":"bad"}'), throwsFormatException);
    expect(vault.value, before);
    expect(repo.data.entries.single.cents, 199);
  });

  test('duplicate backup IDs are blocked', () async {
    await repo.record(cents: 100, kind: 'income', category: 'Other');
    final obj = jsonDecode(repo.exportJson()) as Map<String, dynamic>;
    final data = obj['data'] as Map<String, dynamic>;
    final entry = (data['entries'] as List).single;
    (data['entries'] as List).add(entry);
    await expectLater(repo.importJson(jsonEncode(obj)), throwsFormatException);
    expect(repo.data.entries.length, 1);
  });

  test('currency cannot silently relabel money amounts', () async {
    await repo.setCurrency('EUR');
    expect(repo.data.currency, 'EUR');
    await repo.record(cents: 100, kind: 'income', category: 'Other');
    await expectLater(repo.setCurrency('TRY'), throwsStateError);
    expect(repo.data.currency, 'EUR');
  });

  test('corrupted vault is preserved and blocks new writes', () async {
    final broken = MemoryVault()..value = '{invalid-json';
    final damaged = BudgetRepository(broken);
    await damaged.load();
    expect(damaged.loadError, isNotNull);
    await expectLater(damaged.record(cents: 123, kind: 'income', category: 'Other'), throwsStateError);
    expect(broken.value, '{invalid-json');
    damaged.dispose();
  });

  test('serialized mutations do not drop simultaneous updates', () async {
    await Future.wait(List.generate(30, (_) =>
      repo.record(cents: 100, kind: 'income', category: 'Other')));
    expect(repo.data.entries.length, 30);
    expect(summarize(repo.data, DateTime.now()).income, 3000);
  });
}
