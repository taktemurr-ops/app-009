import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/repository.dart';
import 'ui/pages.dart';
import 'ui/toolkit.dart';
import 'ui/words.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Budget360App());
}

class Budget360App extends StatefulWidget {
  final BudgetRepository? repository;
  const Budget360App({super.key, this.repository});
  @override
  State<Budget360App> createState() => _Budget360AppState();
}

class _Budget360AppState extends State<Budget360App> {
  late final BudgetRepository repo;
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? BudgetRepository(const DeviceVault());
    repo.load();
  }

  @override
  void dispose() {
    if (widget.repository == null) repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repo,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bütçe 360',
      locale: Locale(repo.data.locale),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146F6B)), useMaterial3: true),
      home: !repo.loaded ? const Scaffold(body: Center(child: CircularProgressIndicator())) :
        repo.loadError != null ? _RecoveryScreen(repo: repo) : HomeScreen(repo: repo),
    ),
  );
}

class _RecoveryScreen extends StatelessWidget {
  final BudgetRepository repo;
  const _RecoveryScreen({required this.repo});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Budget data recovery')),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(repo.loadError ?? 'Unknown issue'),
        const SizedBox(height: 12),
        const Text('No stored bytes have been overwritten.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: () async {
          final confirmed = await showDialog<bool>(context: context,
            builder: (c) => AlertDialog(title: const Text('Erase damaged records?'),
              content: const Text('This permanently deletes the inaccessible local data.'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Erase'))]));
          if (confirmed == true) {
            try {await repo.clearAll();} catch (_) { /* Keep recovery screen visible. */ }
          }
        }, child: const Text('Reset encrypted storage')),
      ],
    )),
  );
}

class HomeScreen extends StatefulWidget {
  final BudgetRepository repo;
  const HomeScreen({super.key, required this.repo});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  void changeMonth(DateTime value) => setState(() => month = DateTime(value.year, value.month));

  @override
  Widget build(BuildContext context) {
    final words = Words.of(context);
    final pages = <Widget>[
      OverviewPage(repo: widget.repo, month: month, onMonth: changeMonth),
      TransactionsPage(repo: widget.repo, month: month, onMonth: changeMonth),
      BudgetsPage(repo: widget.repo, month: month),
      GoalsPage(repo: widget.repo),
      ToolkitPage(repo: widget.repo),
    ];
    final labels = [words['dashboard'], words['transactions'], words['budgets'],
      words['goals'], words['tools']];
    return Scaffold(
      appBar: AppBar(title: Text(words['app']), actions: [
        IconButton(tooltip: words['settings'], icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => SettingsPage(repo: widget.repo)))),
      ]),
      body: pages[index],
      bottomNavigationBar: NavigationBar(selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: labels[0]),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: labels[1]),
          NavigationDestination(icon: const Icon(Icons.pie_chart_outline), label: labels[2]),
          NavigationDestination(icon: const Icon(Icons.savings_outlined), label: labels[3]),
          NavigationDestination(icon: const Icon(Icons.apps_outlined), label: labels[4]),
        ]),
    );
  }
}
