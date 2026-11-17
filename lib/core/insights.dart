import 'models.dart';
import 'money.dart';

class BudgetInsight {
  final String title;
  final String detail;
  const BudgetInsight(this.title, this.detail);
}

List<BudgetInsight> generateInsights(BudgetData data, DateTime month) {
  final monthly = summarize(data, month);
  final tips = <BudgetInsight>[];
  if (monthly.income == 0 && monthly.expense == 0) {
    tips.add(const BudgetInsight('Start your journal', 'Record income and expenses to see meaningful insights.'));
    return tips;
  }
  if (monthly.balance < 0) {
    tips.add(const BudgetInsight('Spending exceeds income', 'Review the largest expense categories and reduce non-essential costs.'));
  } else {
    tips.add(const BudgetInsight('Positive monthly balance', 'Consider assigning some of the surplus to a savings goal.'));
  }
  final costs = <String, int>{};
  for (final entry in data.entries) {
    if (entry.kind == 'expense' && monthKey(entry.occurredAt) == monthKey(month)) {
      costs[entry.category] = (costs[entry.category] ?? 0) + entry.cents;
    }
  }
  if (costs.isNotEmpty) {
    final largest = costs.entries.reduce((a,b) => a.value >= b.value ? a : b);
    tips.add(BudgetInsight('Largest expense category', largest.key));
  }
  for (final category in data.budgets) {
    final spent = costs[category.category] ?? 0;
    if (spent > category.cents) {
      tips.add(BudgetInsight('Category over budget', category.category));
    } else if (spent * 100 >= category.cents * 80) {
      tips.add(BudgetInsight('Near category limit', category.category));
    }
  }
  return tips;
}

Map<String, int> expenseBreakdown(BudgetData data, DateTime month) {
  final map = <String, int>{};
  for (final entry in data.entries) {
    if (entry.kind == 'expense' && monthKey(entry.occurredAt) == monthKey(month)) {
      map[entry.category] = (map[entry.category] ?? 0) + entry.cents;
    }
  }
  return map;
}

/// Recurring bill projection is not automatically posted to the ledger.
int projectedMonthlyExpenses(BudgetData data) =>
  data.recurring.where((e) => e.enabled && e.kind == 'expense')
    .fold<int>(0, (a, b) => a + b.cents);

int savingsProgress(BudgetData data) =>
  sumCents(data.goals.map((e) => e.savedCents));
