import 'package:flutter/material.dart';
import '../core/insights.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/repository.dart';
import 'widgets.dart';
import 'words.dart';

class MonthHeader extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChange;
  const MonthHeader({super.key, required this.month, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final w = Words.of(context);
    return Row(children: [
      IconButton(tooltip: w['monthBack'], icon: const Icon(Icons.chevron_left),
        onPressed: () => onChange(DateTime(month.year, month.month - 1))),
      Expanded(child: Center(child: Text(formatMonth(context, month),
        style: Theme.of(context).textTheme.titleMedium))),
      IconButton(tooltip: w['monthNext'], icon: const Icon(Icons.chevron_right),
        onPressed: () => onChange(DateTime(month.year, month.month + 1))),
    ]);
  }
}

class OverviewPage extends StatelessWidget {
  final BudgetRepository repo;
  final DateTime month;
  final ValueChanged<DateTime> onMonth;
  const OverviewPage({super.key, required this.repo, required this.month, required this.onMonth});
  @override
  Widget build(BuildContext context) {
    final w = Words.of(context);
    final data = repo.data;
    final summary = summarize(data, month);
    final costs = expenseBreakdown(data, month).entries.toList()
      ..sort((a,b) => b.value.compareTo(a.value));
    final tips = generateInsights(data, month);
    return ListView(padding: const EdgeInsets.all(16), children: [
      MonthHeader(month: month, onChange: onMonth),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(
        w['privacy'], style: Theme.of(context).textTheme.bodyMedium))),
      const SizedBox(height: 8),
      statCard(context, w['income'], formatMoney(context, summary.income, data.currency),
        icon: Icons.south_west, color: Colors.green),
      statCard(context, w['expense'], formatMoney(context, summary.expense, data.currency),
        icon: Icons.north_east, color: Colors.deepOrange),
      statCard(context, w['balance'], formatMoney(context, summary.balance, data.currency),
        icon: Icons.account_balance_wallet),
      sectionTitle(context, w['spending']),
      if (costs.isEmpty) Text(w['empty']),
      ...costs.map((row) => ListTile(
        title: Text(translatedCategory(context, row.key)),
        trailing: Text(formatMoney(context, row.value, data.currency)),
        subtitle: LinearProgressIndicator(value: summary.expense <= 0 ? 0 :
          (row.value / summary.expense).clamp(0, 1).toDouble()),
      )),
      sectionTitle(context, w['insights']),
      ...tips.map((tip) => Card(child: ListTile(leading: const Icon(Icons.lightbulb_outline),
        title: Text(tip.title), subtitle: Text(tip.detail)))),
      const SizedBox(height: 20),
    ]);
  }
}

class TransactionsPage extends StatefulWidget {
  final BudgetRepository repo;
  final DateTime month;
  final ValueChanged<DateTime> onMonth;
  const TransactionsPage({super.key, required this.repo, required this.month, required this.onMonth});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String query = '';
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final w = Words.of(context);
    final data = widget.repo.data;
    final items = data.entries.where((e) => monthKey(e.occurredAt) == monthKey(widget.month))
      .where((e) => filter == 'all' || e.kind == filter)
      .where((e) => '${e.category} ${e.note} ${e.member}'.toLowerCase().contains(query.toLowerCase()))
      .toList()..sort((a,b) => b.occurredAt.compareTo(a.occurredAt));
    return Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [
      MonthHeader(month: widget.month, onChange: widget.onMonth),
      TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
        hintText: w['transactions'], border: const OutlineInputBorder()),
        onChanged: (value) => setState(() => query = value)),
      const SizedBox(height: 10),
      SegmentedButton<String>(segments: [
        ButtonSegment(value: 'all', label: Text(w['all'])),
        ButtonSegment(value: 'income', label: Text(w['income'])),
        ButtonSegment(value: 'expense', label: Text(w['expense'])),
      ], selected: {filter}, onSelectionChanged: (value) => setState(() => filter = value.first)),
      const SizedBox(height: 12),
      if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(w['empty'])),
      ...items.map((e) => Card(child: ListTile(
        leading: Icon(e.kind == 'income' ? Icons.add_circle_outline : Icons.remove_circle_outline,
          color: e.kind == 'income' ? Colors.green : Colors.deepOrange),
        title: Text('${translatedCategory(context, e.category)} · ${formatMoney(context, e.cents, data.currency)}'),
        subtitle: Text('${formatDate(context, e.occurredAt)} · ${e.member}${e.note.isNotEmpty ? '\n${e.note}' : ''}'),
        isThreeLine: e.note.isNotEmpty,
        trailing: IconButton(tooltip: w['delete'], icon: const Icon(Icons.delete_outline),
          onPressed: () async {if (await askConfirm(context, title: w['delete'], body: w['permanent'])) {
            if (context.mounted) await safely(context, () => widget.repo.removeEntry(e.id));
          }}),
      ))),
      const SizedBox(height: 80),
    ]), floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _addEntry(context), icon: const Icon(Icons.add), label: Text(w['add'])),
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    final w = Words.of(context);
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var category = 'Food';
    var kind = 'expense';
    var date = DateTime.now();
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: Text(w['newTransaction']),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(segments: [
              ButtonSegment(value: 'expense', label: Text(w['expense'])),
              ButtonSegment(value: 'income', label: Text(w['income'])),
            ], selected: {kind}, onSelectionChanged: (v) => update(() => kind = v.first)),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: w['amount'], border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: category, isExpanded: true,
              decoration: InputDecoration(labelText: w['category'], border: const OutlineInputBorder()),
              items: categoryNames.map((e) => DropdownMenuItem(value: e,
                child: Text(translatedCategory(dialogContext, e)))).toList(),
              onChanged: (value) {if (value != null) update(() => category = value);}),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, maxLength: 1000,
              decoration: InputDecoration(labelText: w['note'], border: const OutlineInputBorder())),
            OutlinedButton.icon(onPressed: () async {
              final picked = await showDatePicker(context: dialogContext, initialDate: date,
                firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) update(() => date = picked);
            }, icon: const Icon(Icons.calendar_month), child: Text(formatDate(dialogContext, date))),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(w['cancel'])),
            FilledButton(onPressed: () async {
              final amount = parseMoney(amountCtrl.text);
              if (amount == null) {ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(w['invalidAmount']))); return;}
              try {
                await widget.repo.record(cents: amount, kind: kind, category: category,
                  note: noteCtrl.text, date: date);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${w['unavailable']}: $error')));
              }
            }, child: Text(w['save'])),
          ],
        ),
      ));
    } finally {
      amountCtrl.dispose();
      noteCtrl.dispose();
    }
  }
}

class BudgetsPage extends StatelessWidget {
  final BudgetRepository repo;
  final DateTime month;
  const BudgetsPage({super.key, required this.repo, required this.month});
  @override
  Widget build(BuildContext context) {
    final w = Words.of(context);
    final budgets = [...repo.data.budgets]..sort((a,b) => a.category.compareTo(b.category));
    return Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [
      sectionTitle(context, '${w['budgets']} · ${formatMonth(context, month)}'),
      if (budgets.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(w['empty'])),
      ...budgets.map((b) {
        final used = spentInCategory(repo.data, month, b.category);
        final left = b.cents - used;
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(translatedCategory(context,b.category),
              style: Theme.of(context).textTheme.titleMedium)),
              IconButton(tooltip: w['delete'], onPressed: () async {
                if (await askConfirm(context,title:w['delete'],body:w['permanent']) && context.mounted) {
                  await safely(context, () => repo.removeBudget(b.category));
                }
              },icon: const Icon(Icons.delete_outline))]),
            Text('${w['spending']}: ${formatMoney(context,used,repo.data.currency)} / ${formatMoney(context,b.cents,repo.data.currency)}'),
            const SizedBox(height: 8), LinearProgressIndicator(value: (used / b.cents).clamp(0,1).toDouble(),
              color: used > b.cents ? Colors.red : Colors.teal),
            const SizedBox(height: 8),
            Text('${w['remaining']}: ${formatMoney(context,left,repo.data.currency)}'),
          ],
        )));
      }),
      const SizedBox(height: 80),
    ]), floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _newBudget(context), icon: const Icon(Icons.add), label: Text(w['add'])),
    );
  }

  Future<void> _newBudget(BuildContext context) async {
    final w=Words.of(context);
    final category=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(
      title:Text(w['category']),children:categoryNames.map((e)=>SimpleDialogOption(
        onPressed:()=>Navigator.pop(c,e),child:Text(translatedCategory(c,e)))).toList()));
    if(category == null || !context.mounted)return;
    final money=await askAmount(context,w['limit']);
    if(money==null || !context.mounted)return;
    await safely(context,()=>repo.setBudget(category,money));
  }
}

class GoalsPage extends StatelessWidget {
  final BudgetRepository repo;
  const GoalsPage({super.key, required this.repo});
  @override
  Widget build(BuildContext context) {
    final w=Words.of(context);
    return Scaffold(body:ListView(padding:const EdgeInsets.all(16),children:[
      sectionTitle(context,w['goals']),
      Text(w['notAdvice']),
      if(repo.data.goals.isEmpty) Padding(padding:const EdgeInsets.all(16),child:Text(w['empty'])),
      ...repo.data.goals.map((g)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(g.title,style:Theme.of(context).textTheme.titleMedium)),
            IconButton(tooltip:w['delete'],onPressed:() async {
              if(await askConfirm(context,title:w['delete'],body:w['permanent'])&&context.mounted){
                await safely(context,()=>repo.removeGoal(g.id));
              }
            },icon:const Icon(Icons.delete_outline))]),
          Text('${w['saved']}: ${formatMoney(context,g.savedCents,repo.data.currency)}'),
          Text('${w['target']}: ${formatMoney(context,g.targetCents,repo.data.currency)}'),
          const SizedBox(height:8),
          LinearProgressIndicator(value:(g.savedCents/g.targetCents).clamp(0,1).toDouble()),
          const SizedBox(height:8),
          if(g.savedCents<g.targetCents) OutlinedButton.icon(onPressed:() async {
            final cents=await askAmount(context,w['contribute']);
            if(cents!=null&&context.mounted)await safely(context,()=>repo.contribute(g.id,cents));
          },icon:const Icon(Icons.savings),label:Text(w['contribute'])),
          if(g.savedCents==g.targetCents)Text(w['congratulations']),
        ],
      )))),
      const SizedBox(height:80),
    ]),floatingActionButton:FloatingActionButton.extended(
      onPressed:() async {
        final title=await askText(context,title:w['newGoal']);
        if(title==null||title.isEmpty||!context.mounted)return;
        final money=await askAmount(context,w['target']);
        if(money!=null&&context.mounted)await safely(context,()=>repo.addGoal(title,money));
      },icon:const Icon(Icons.add),label:Text(w['add'])),
    );
  }
}

class ReportsPage extends StatelessWidget {
  final BudgetRepository repo;
  const ReportsPage({super.key,required this.repo});
  @override
  Widget build(BuildContext context) {
    final w=Words.of(context);
    final now=DateTime.now();
    return Scaffold(appBar:AppBar(title:Text(w['reports'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      sectionTitle(context,w['lastMonths']),
      for(var i=0;i<6;i++) Builder(builder:(context){
        final month=DateTime(now.year,now.month-i);
        final summary=summarize(repo.data,month);
        return Card(child:ListTile(title:Text(formatMonth(context,month)),
          subtitle:Text('${w['income']}: ${formatMoney(context,summary.income,repo.data.currency)}\n${w['expense']}: ${formatMoney(context,summary.expense,repo.data.currency)}'),
          trailing:Text(formatMoney(context,summary.balance,repo.data.currency))));
      }),
      sectionTitle(context,w['plannedExpenses']),
      Text(formatMoney(context,projectedMonthlyExpenses(repo.data),repo.data.currency)),
      sectionTitle(context,w['saved']),
      Text(formatMoney(context,savingsProgress(repo.data),repo.data.currency)),
    ]));
  }
}
