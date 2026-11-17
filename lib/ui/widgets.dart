import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import 'words.dart';

String formatMoney(BuildContext context, int cents, String currency) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return NumberFormat.simpleCurrency(locale: locale, name: currency)
    .format(cents / 100);
}

String formatMonth(BuildContext context, DateTime date) =>
  DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag()).format(date);

String formatDate(BuildContext context, DateTime date) =>
  DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(date);

String translatedCategory(BuildContext context, String category) {
  final text = Words.of(context);
  return switch (category) {
    'Food' => text['food'], 'Housing' => text['housing'],
    'Bills' => text['bills'], 'Transport' => text['transport'],
    'Health' => text['health'], 'Education' => text['education'],
    'Family' => text['familyCategory'], 'Shopping' => text['shopping'],
    'Entertainment' => text['entertainment'], 'Savings' => text['savings'],
    'Other' => text['other'], _ => category,
  };
}

Widget sectionTitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 10),
  child: Text(text, style: Theme.of(context).textTheme.titleLarge),
);

Widget statCard(BuildContext context, String title, String value,
    {IconData icon = Icons.paid, Color? color}) => Card(
  child: Padding(padding: const EdgeInsets.all(16), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
      const SizedBox(height: 8), Text(title), const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  )),
);

Future<bool> askConfirm(BuildContext context, {required String title, required String body}) async {
  final w = Words.of(context);
  return await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text(title), content: Text(body), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(w['cancel'])),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(w['confirm'])),
    ],
  )) ?? false;
}

Future<String?> askText(BuildContext context, {required String title,
    String initial = '', int maxLength = 180, int maxLines = 1}) async {
  final w = Words.of(context);
  final ctrl = TextEditingController(text: initial);
  try {
    return await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text(title), content: TextField(controller: ctrl, autofocus: true,
        maxLength: maxLength, maxLines: maxLines,
        decoration: const InputDecoration(border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(w['cancel'])),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(w['save'])),
      ],
    ));
  } finally {
    ctrl.dispose();
  }
}

Future<int?> askAmount(BuildContext context, String title) async {
  final text = await askText(context, title: title, maxLength: 40);
  if (text == null) return null;
  final amount = parseMoney(text);
  if (amount == null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Words.of(context)['invalidAmount'])));
  }
  return amount;
}

Future<void> safely(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Words.of(context)['success'])));
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${Words.of(context)['unavailable']}: $error')));
  }
}
