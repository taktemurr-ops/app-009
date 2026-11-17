import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/insights.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/repository.dart';
import 'pages.dart';
import 'widgets.dart';
import 'words.dart';

class ToolkitPage extends StatelessWidget {
  final BudgetRepository repo;
  const ToolkitPage({super.key,required this.repo});

  @override
  Widget build(BuildContext context) {
    final w=Words.of(context);
    final tools=<({String key,IconData icon,Widget Function() page})>[
      (key:'recurring',icon:Icons.autorenew,page:()=>RecurringPage(repo:repo)),
      (key:'checklist',icon:Icons.checklist,page:()=>TasksPage(repo:repo)),
      (key:'journal',icon:Icons.menu_book,page:()=>JournalPage(repo:repo)),
      (key:'household',icon:Icons.groups_2_outlined,page:()=>HouseholdPage(repo:repo)),
      (key:'reports',icon:Icons.bar_chart,page:()=>ReportsPage(repo:repo)),
      (key:'coach',icon:Icons.tips_and_updates_outlined,page:()=>CoachPage(repo:repo)),
      (key:'academy',icon:Icons.school_outlined,page:()=>AcademyPage()),
      (key:'quickTools',icon:Icons.calculate_outlined,page:()=>CalculatorPage(repo:repo)),
      (key:'templates',icon:Icons.view_module_outlined,page:()=>TemplatesPage(repo:repo)),
      (key:'challenges',icon:Icons.emoji_events_outlined,page:()=>ChallengePage(repo:repo)),
      (key:'settings',icon:Icons.settings_outlined,page:()=>SettingsPage(repo:repo)),
    ];
    return ListView(padding:const EdgeInsets.all(16),children:[
      sectionTitle(context,w['tools']),
      Text(w['localOnly']),
      const SizedBox(height:10),
      ...tools.map((item)=>Card(child:ListTile(leading:Icon(item.icon),title:Text(w[item.key]),
        trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,
          MaterialPageRoute<void>(builder:(_)=>item.page()))))),
      sectionTitle(context,w['about']),
      const Text('APP-009 • Budget 360\nOffline-first personal and household budgeting.\nNo banking, investment trading or remote account access.'),
      const SizedBox(height:24),
    ]);
  }
}

class RecurringPage extends StatelessWidget {
  final BudgetRepository repo;
  const RecurringPage({super.key,required this.repo});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['recurring'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      Text(w['plannedExpenses'],style:Theme.of(context).textTheme.titleMedium),
      Text(formatMoney(context,projectedMonthlyExpenses(repo.data),repo.data.currency)),
      FilledButton.icon(onPressed:()async {
        try{
          final count=await repo.applyDue(DateTime.now());
          if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content:Text('${w['success']}: $count')));
        }catch(error){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text('${w['unavailable']}: $error')));}
      },icon:const Icon(Icons.play_arrow),label:Text(w['apply'])),
      if(repo.data.recurring.isEmpty) Padding(padding:const EdgeInsets.all(16),child:Text(w['empty'])),
      ...repo.data.recurring.map((rule)=>Card(child:ListTile(
        title:Text(rule.title),
        subtitle:Text('${rule.day} · ${translatedCategory(context,rule.category)} · ${rule.kind=='income'?w['income']:w['expense']}'),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          Text(formatMoney(context,rule.cents,repo.data.currency)),
          IconButton(tooltip:w['delete'],icon:const Icon(Icons.delete_outline),onPressed:()async {
            if(await askConfirm(context,title:w['delete'],body:w['permanent'])&&context.mounted){
              await safely(context,()=>repo.removeRecurring(rule.id));
            }
          }),
        ]),
      ))),
      const SizedBox(height:80),
    ]),floatingActionButton:FloatingActionButton.extended(onPressed:()=>_newRule(context),
      icon:const Icon(Icons.add),label:Text(w['add'])));
  }

  Future<void> _newRule(BuildContext context) async {
    final w=Words.of(context);
    final title=await askText(context,title:w['title']);
    if(title==null||title.isEmpty||!context.mounted)return;
    final amount=await askAmount(context,w['amount']);
    if(amount==null||!context.mounted)return;
    final dayText=await askText(context,title:w['day']);
    final day=dayText==null?null:int.tryParse(normalizeDigits(dayText));
    if(day==null||day<1||day>31||!context.mounted)return;
    final category=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(
      title:Text(w['category']),children:categoryNames.map((name)=>SimpleDialogOption(
        child:Text(translatedCategory(c,name)),onPressed:()=>Navigator.pop(c,name))).toList()));
    if(category==null||!context.mounted)return;
    final kind=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(
      title:Text(w['income']),children:[
        SimpleDialogOption(child:Text(w['income']),onPressed:()=>Navigator.pop(c,'income')),
        SimpleDialogOption(child:Text(w['expense']),onPressed:()=>Navigator.pop(c,'expense')),
      ]));
    if(kind==null||!context.mounted)return;
    await safely(context,()=>repo.addRecurring(title:title,cents:amount,
      category:category,kind:kind,day:day));
  }
}

class TasksPage extends StatelessWidget {
  final BudgetRepository repo;
  const TasksPage({super.key,required this.repo});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['projects'])),body:ListView(children:[
      if(repo.data.checklist.isEmpty)Padding(padding:const EdgeInsets.all(20),child:Text(w['empty'])),
      ...repo.data.checklist.map((item)=>CheckboxListTile(value:item.done,title:Text(item.title),
        secondary:IconButton(tooltip:w['delete'],icon:const Icon(Icons.delete_outline),
          onPressed:()async {if(await askConfirm(context,title:w['delete'],body:w['permanent'])&&context.mounted){
            await safely(context,()=>repo.removeChecklist(item.id));}}),
        onChanged:(_)=>safely(context,()=>repo.toggleChecklist(item.id)))),
      const SizedBox(height:80),
    ]),floatingActionButton:FloatingActionButton.extended(onPressed:()async {
      final title=await askText(context,title:w['projectPrompt']);
      if(title!=null&&title.isNotEmpty&&context.mounted)await safely(context,()=>repo.addChecklist(title));
    },icon:const Icon(Icons.add),label:Text(w['add'])));
  }
}

class JournalPage extends StatelessWidget {
  final BudgetRepository repo;
  const JournalPage({super.key,required this.repo});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['journal'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      if(repo.data.journal.isEmpty)Text(w['empty']),
      ...repo.data.journal.map((n)=>Card(child:ListTile(
        title:Text(n.text),subtitle:Text(formatDate(context,n.at)),
        trailing:IconButton(tooltip:w['delete'],icon:const Icon(Icons.delete_outline),onPressed:()async {
          if(await askConfirm(context,title:w['delete'],body:w['permanent'])&&context.mounted){
            await safely(context,()=>repo.removeJournal(n.id));
          }
        }),
      ))),
      const SizedBox(height:80),
    ]),floatingActionButton:FloatingActionButton.extended(onPressed:()async {
      final text=await askText(context,title:w['note'],maxLength:1000,maxLines:4);
      if(text!=null&&text.isNotEmpty&&context.mounted)await safely(context,()=>repo.addJournal(text));
    },icon:const Icon(Icons.add),label:Text(w['add'])));
  }
}

class HouseholdPage extends StatelessWidget {
  final BudgetRepository repo;
  const HouseholdPage({super.key,required this.repo});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['household'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      Text(w['offlineFamily']),
      ...repo.data.members.map((name)=>ListTile(
        leading:Icon(name==repo.data.member?Icons.radio_button_checked:Icons.radio_button_unchecked),
        title:Text(name),onTap:()=>safely(context,()=>repo.setMember(name)))),
      FilledButton.icon(onPressed:()async {
        final name=await askText(context,title:w['member']);
        if(name!=null&&name.isNotEmpty&&context.mounted)await safely(context,()=>repo.addMember(name));
      },icon:const Icon(Icons.person_add_alt),label:Text(w['add'])),
    ]));
  }
}

class CoachPage extends StatelessWidget {
  final BudgetRepository repo;
  const CoachPage({super.key,required this.repo});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    final insights=generateInsights(repo.data,DateTime.now());
    return Scaffold(appBar:AppBar(title:Text(w['coach'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      Text(w['notAdvice']),
      sectionTitle(context,w['insights']),
      ...insights.map((e)=>Card(child:ListTile(leading:const Icon(Icons.lightbulb_outline),
        title:Text(e.title),subtitle:Text(e.detail)))),
      sectionTitle(context,w['academy']),
      for(var i=1;i<=4;i++) Card(child:ListTile(
        leading:const Icon(Icons.school),title:Text(w['tip$i']))),
    ]));
  }
}

class AcademyPage extends StatelessWidget {
  const AcademyPage({super.key});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['academy'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      Text(w['notAdvice']),
      sectionTitle(context,w['academy']),
      for(var i=1;i<=4;i++) ExpansionTile(
        leading:const Icon(Icons.menu_book_outlined),title:Text('${i.toString().padLeft(2,'0')} · ${w['dailyTip']}'),
        children:[Padding(padding:const EdgeInsets.all(16),child:Text(w['tip$i']))]),
      sectionTitle(context,w['privacy']),
      Text(w['localOnly']),
    ]));
  }
}

class CalculatorPage extends StatefulWidget {
  final BudgetRepository repo;
  const CalculatorPage({super.key,required this.repo});
  @override
  State<CalculatorPage> createState()=>_CalculatorPageState();
}
class _CalculatorPageState extends State<CalculatorPage>{
  final _target=TextEditingController();
  final _months=TextEditingController(text:'12');
  int? _monthly;
  @override
  void dispose(){_target.dispose();_months.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['quickTools'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      TextField(controller:_target,keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:InputDecoration(labelText:w['target'],border:const OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:_months,keyboardType:TextInputType.number,
        decoration:InputDecoration(labelText:w['month'],border:const OutlineInputBorder())),
      const SizedBox(height:12),
      FilledButton(onPressed:(){
        final total=parseMoney(_target.text);
        final months=int.tryParse(normalizeDigits(_months.text));
        if(total==null||months==null||months<1||months>600){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(w['invalidAmount'])));return;
        }
        setState(()=>_monthly=(total+months-1)~/months);
      },child:Text(w['quickTools'])),
      if(_monthly!=null)statCard(context,w['monthProjection'],formatMoney(context,_monthly!,widget.repo.data.currency)),
      const SizedBox(height:18),Text(w['notAdvice']),
    ]));
  }
}

class TemplatesPage extends StatelessWidget {
  final BudgetRepository repo;
  const TemplatesPage({super.key,required this.repo});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['templates'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      sectionTitle(context,'50 / 30 / 20'),
      const Text('50% Housing · 30% Shopping · 20% Savings'),
      const SizedBox(height:14),
      FilledButton.icon(onPressed:()async {
        final money=await askAmount(context,w['income']);
        if(money==null||!context.mounted)return;
        if(!await askConfirm(context,title:w['templates'],body:w['importConfirm']))return;
        if(!context.mounted)return;
        await safely(context,()=>repo.applyStarterTemplate(money));
      },icon:const Icon(Icons.add_chart),label:Text(w['save'])),
      sectionTitle(context,w['about']),
      Text(w['notAdvice']),
    ]));
  }
}

class ChallengePage extends StatelessWidget {
  final BudgetRepository repo;
  const ChallengePage({super.key,required this.repo});
  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    final month=DateTime.now();
    final total=summarize(repo.data,month);
    final target=repo.data.goals.fold<int>(0,(acc,g)=>acc+g.targetCents);
    final saved=savingsProgress(repo.data);
    return Scaffold(appBar:AppBar(title:Text(w['challenges'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      statCard(context,w['balance'],formatMoney(context,total.balance,repo.data.currency)),
      statCard(context,w['saved'],formatMoney(context,saved,repo.data.currency),icon:Icons.emoji_events_outlined),
      if(target>0)LinearProgressIndicator(value:(saved/target).clamp(0,1).toDouble()),
      const SizedBox(height:12),
      Text(w['tip3']),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(
        builder:(_)=>Scaffold(appBar:AppBar(title:Text(w['goals'])),body:GoalsPage(repo:repo)))),
        icon:const Icon(Icons.flag_outlined),label:Text(w['goals'])),
    ]));
  }
}

class SettingsPage extends StatelessWidget {
  final BudgetRepository repo;
  const SettingsPage({super.key,required this.repo});

  @override
  Widget build(BuildContext context){
    final w=Words.of(context);
    return Scaffold(appBar:AppBar(title:Text(w['settings'])),body:ListView(padding:const EdgeInsets.all(16),children:[
      sectionTitle(context,w['language']),
      DropdownButtonFormField<String>(initialValue:repo.data.locale,
        decoration:InputDecoration(border:const OutlineInputBorder(),labelText:w['language']),
        items:const [DropdownMenuItem(value:'tr',child:Text('Türkçe')),
          DropdownMenuItem(value:'en',child:Text('English')),
          DropdownMenuItem(value:'ar',child:Text('العربية'))],
        onChanged:(val){if(val!=null)safely(context,()=>repo.setLocale(val));}),
      sectionTitle(context,w['currency']),
      Text(w['noExchange']),
      DropdownButtonFormField<String>(initialValue:repo.data.currency,
        decoration:InputDecoration(border:const OutlineInputBorder(),labelText:w['currency']),
        items:supportedCurrencies.map((code)=>DropdownMenuItem(value:code,child:Text(code))).toList(),
        onChanged:(val){if(val!=null)safely(context,()=>repo.setCurrency(val));}),
      sectionTitle(context,w['privacySettings']),
      Text(w['privacy']),
      const SizedBox(height:16),
      OutlinedButton.icon(onPressed:()async {
        if(!await askConfirm(context,title:w['export'],body:w['exportConfirm']))return;
        await Clipboard.setData(ClipboardData(text:repo.exportJson()));
        if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(w['exported'])));
      },icon:const Icon(Icons.copy_all_outlined),label:Text(w['export'])),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:()async {
        final raw=await askText(context,title:w['backupHint'],maxLength:10000000,maxLines:7);
        if(raw==null||raw.trim().isEmpty||!context.mounted)return;
        if(!await askConfirm(context,title:w['import'],body:w['importConfirm']))return;
        if(context.mounted)await safely(context,()=>repo.importJson(raw));
      },icon:const Icon(Icons.upload_file),label:Text(w['import'])),
      const SizedBox(height:10),Text(w['backupWarning']),
      const SizedBox(height:18),
      FilledButton.icon(onPressed:()async {
        if(!await askConfirm(context,title:w['reset'],body:w['permanent']))return;
        if(context.mounted)await safely(context,repo.clearAll);
      },icon:const Icon(Icons.delete_forever),label:Text(w['reset'])),
      const SizedBox(height:25),Text(w['notAdvice']),
    ]));
  }
}
