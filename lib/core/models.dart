import 'money.dart';

String _requiredText(dynamic value, String label, {int max = 180}) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw FormatException('Invalid $label');
  }
  return value.trim();
}

String _optionalText(dynamic value, String label, {int max = 1000}) {
  if (value is! String || value.length > max) throw FormatException('Invalid $label');
  return value;
}

int _positiveInt(dynamic value, String label, {int limit = 999999999999999}) {
  if (value is! int || value <= 0 || value > limit) throw FormatException('Invalid $label');
  return value;
}

DateTime _date(dynamic raw) {
  if (raw is! String) throw const FormatException('Invalid date');
  return DateTime.parse(raw);
}

Map<String, dynamic> _json(dynamic raw) {
  if (raw is! Map) throw const FormatException('Invalid object');
  return Map<String, dynamic>.from(raw);
}

List<T> _items<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List || raw.length > 100000) throw const FormatException('Invalid list');
  return raw.map((e) => parse(_json(e))).toList(growable: false);
}

const categoryNames = <String>[
  'Food', 'Housing', 'Bills', 'Transport', 'Health', 'Education',
  'Family', 'Shopping', 'Entertainment', 'Savings', 'Other',
];

class MoneyEntry {
  final String id;
  final DateTime occurredAt;
  final int cents;
  final String kind; // expense | income
  final String category;
  final String note;
  final String member;
  final String? recurringId;

  const MoneyEntry({required this.id, required this.occurredAt, required this.cents,
    required this.kind, required this.category, required this.note,
    required this.member, this.recurringId});

  Map<String, dynamic> toJson() => {
    'id': id, 'occurredAt': occurredAt.toIso8601String(), 'cents': cents,
    'kind': kind, 'category': category, 'note': note, 'member': member,
    'recurringId': recurringId,
  };
  factory MoneyEntry.fromJson(Map<String, dynamic> data) {
    final kind = _requiredText(data['kind'], 'kind');
    if (kind != 'expense' && kind != 'income') throw const FormatException('Invalid kind');
    final rid = data['recurringId'];
    if (rid != null && (rid is! String || rid.isEmpty || rid.length > 180)) {
      throw const FormatException('Invalid recurring reference');
    }
    return MoneyEntry(
      id: _requiredText(data['id'], 'id'),
      occurredAt: _date(data['occurredAt']),
      cents: _positiveInt(data['cents'], 'cents'),
      kind: kind,
      category: _requiredText(data['category'], 'category'),
      note: _optionalText(data['note'], 'note'),
      member: _requiredText(data['member'], 'member'), recurringId: rid as String?,
    );
  }
}

class CategoryBudget {
  final String category;
  final int cents;
  const CategoryBudget(this.category, this.cents);
  Map<String, dynamic> toJson() => {'category': category, 'cents': cents};
  factory CategoryBudget.fromJson(Map<String, dynamic> v) => CategoryBudget(
    _requiredText(v['category'], 'category'), _positiveInt(v['cents'], 'budget'));
}

class SavingsGoal {
  final String id;
  final String title;
  final int targetCents;
  final int savedCents;
  const SavingsGoal({required this.id, required this.title,
    required this.targetCents, required this.savedCents});
  Map<String, dynamic> toJson() => {'id': id, 'title': title,
    'targetCents': targetCents, 'savedCents': savedCents};
  factory SavingsGoal.fromJson(Map<String, dynamic> v) {
    final target = _positiveInt(v['targetCents'], 'target');
    final saved = v['savedCents'];
    if (saved is! int || saved < 0 || saved > target) throw const FormatException('Invalid savings');
    return SavingsGoal(id: _requiredText(v['id'], 'id'),
      title: _requiredText(v['title'], 'title'), targetCents: target, savedCents: saved);
  }
}

class RecurringRule {
  final String id;
  final String title;
  final int cents;
  final String category;
  final String kind;
  final int day;
  final bool enabled;
  const RecurringRule({required this.id, required this.title,
    required this.cents, required this.category, required this.kind,
    required this.day, this.enabled = true});
  Map<String, dynamic> toJson() => {'id': id, 'title': title,
    'cents': cents, 'category': category, 'kind': kind,
    'day': day, 'enabled': enabled};
  factory RecurringRule.fromJson(Map<String, dynamic> v) {
    final kind = _requiredText(v['kind'], 'kind');
    if (!['expense', 'income'].contains(kind)) throw const FormatException('Invalid recurring kind');
    final day = v['day'];
    if (day is! int || day < 1 || day > 31) throw const FormatException('Invalid day');
    final enabled = v['enabled'];
    if (enabled is! bool) throw const FormatException('Invalid enabled');
    return RecurringRule(id: _requiredText(v['id'], 'id'), title: _requiredText(v['title'], 'title'),
      cents: _positiveInt(v['cents'], 'amount'), category: _requiredText(v['category'], 'category'),
      kind: kind, day: day, enabled: enabled);
  }
}

class ChecklistItem {
  final String id;
  final String title;
  final bool done;
  const ChecklistItem({required this.id, required this.title, this.done = false});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory ChecklistItem.fromJson(Map<String, dynamic> v) {
    if (v['done'] is! bool) throw const FormatException('Invalid checkbox');
    return ChecklistItem(id: _requiredText(v['id'], 'id'),
      title: _requiredText(v['title'], 'title'), done: v['done'] as bool);
  }
}

class JournalNote {
  final String id;
  final DateTime at;
  final String text;
  const JournalNote(this.id, this.at, this.text);
  Map<String, dynamic> toJson() => {'id': id, 'at': at.toIso8601String(), 'text': text};
  factory JournalNote.fromJson(Map<String, dynamic> v) => JournalNote(
    _requiredText(v['id'], 'id'), _date(v['at']), _requiredText(v['text'], 'text', max: 1000));
}

class BudgetData {
  final String currency;
  final String member;
  final String locale;
  final List<String> members;
  final List<MoneyEntry> entries;
  final List<CategoryBudget> budgets;
  final List<SavingsGoal> goals;
  final List<RecurringRule> recurring;
  final List<ChecklistItem> checklist;
  final List<JournalNote> journal;

  const BudgetData({this.currency = 'TRY', this.member = 'Me', this.locale = 'tr',
    this.members = const ['Me'], this.entries = const [], this.budgets = const [],
    this.goals = const [], this.recurring = const [], this.checklist = const [],
    this.journal = const []});

  BudgetData copyWith({String? currency, String? member, String? locale,
    List<String>? members, List<MoneyEntry>? entries, List<CategoryBudget>? budgets,
    List<SavingsGoal>? goals, List<RecurringRule>? recurring,
    List<ChecklistItem>? checklist, List<JournalNote>? journal}) => BudgetData(
      currency: currency ?? this.currency, member: member ?? this.member,
      locale: locale ?? this.locale, members: members ?? this.members,
      entries: entries ?? this.entries, budgets: budgets ?? this.budgets,
      goals: goals ?? this.goals, recurring: recurring ?? this.recurring,
      checklist: checklist ?? this.checklist, journal: journal ?? this.journal);

  Map<String, dynamic> toJson() => {
    'currency': currency, 'member': member, 'locale': locale,
    'members': members,
    'entries': entries.map((e) => e.toJson()).toList(),
    'budgets': budgets.map((e) => e.toJson()).toList(),
    'goals': goals.map((e) => e.toJson()).toList(),
    'recurring': recurring.map((e) => e.toJson()).toList(),
    'checklist': checklist.map((e) => e.toJson()).toList(),
    'journal': journal.map((e) => e.toJson()).toList(),
  };

  factory BudgetData.fromJson(Map<String, dynamic> v) {
    final currency = _requiredText(v['currency'], 'currency', max: 3);
    if (!supportedCurrencies.contains(currency)) throw const FormatException('Invalid currency');
    final locale = _requiredText(v['locale'], 'locale', max: 2);
    if (!['tr', 'en', 'ar'].contains(locale)) throw const FormatException('Invalid locale');
    if (v['members'] is! List) throw const FormatException('Invalid members');
    final members = (v['members'] as List).map((e) => _requiredText(e, 'member')).toList();
    if (members.isEmpty || members.length > 20 || members.toSet().length != members.length) {
      throw const FormatException('Invalid household');
    }
    final member = _requiredText(v['member'], 'member');
    if (!members.contains(member)) throw const FormatException('Missing active member');
    final data = BudgetData(currency: currency, member: member, locale: locale,
      members: members, entries: _items(v['entries'], MoneyEntry.fromJson),
      budgets: _items(v['budgets'], CategoryBudget.fromJson),
      goals: _items(v['goals'], SavingsGoal.fromJson),
      recurring: _items(v['recurring'], RecurringRule.fromJson),
      checklist: _items(v['checklist'], ChecklistItem.fromJson),
      journal: _items(v['journal'], JournalNote.fromJson));
    _unique(data.entries.map((e) => e.id));
    _unique(data.goals.map((e) => e.id));
    _unique(data.recurring.map((e) => e.id));
    _unique(data.checklist.map((e) => e.id));
    _unique(data.journal.map((e) => e.id));
    _unique(data.budgets.map((e) => e.category));
    return data;
  }
}

void _unique(Iterable<String> ids) {
  final list = ids.toList();
  if (list.toSet().length != list.length) throw const FormatException('Duplicate identifiers');
}

class MonthlySummary {
  final int income;
  final int expense;
  const MonthlySummary(this.income, this.expense);
  int get balance => income - expense;
}

MonthlySummary summarize(BudgetData data, DateTime month) {
  var income = 0;
  var expense = 0;
  for (final entry in data.entries) {
    if (monthKey(entry.occurredAt) != monthKey(month)) continue;
    if (entry.kind == 'income') {
      income += entry.cents;
    } else {
      expense += entry.cents;
    }
  }
  return MonthlySummary(income, expense);
}

int spentInCategory(BudgetData data, DateTime month, String category) =>
  data.entries.where((e) => e.kind == 'expense' && e.category == category &&
    monthKey(e.occurredAt) == monthKey(month))
    .fold<int>(0, (total, e) => total + e.cents);
