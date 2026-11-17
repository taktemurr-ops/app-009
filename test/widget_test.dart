import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butce_360/core/repository.dart';
import 'package:butce_360/main.dart';

void main() {
  testWidgets('home loads with Turkish navigation and privacy text', (tester) async {
    final repo = BudgetRepository(MemoryVault());
    await tester.pumpWidget(Budget360App(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('Bütçe 360'), findsWidgets);
    expect(find.text('Özet'), findsWidgets);
    expect(find.textContaining('şifreli'), findsWidgets);
    repo.dispose();
  });

  testWidgets('switching app language to Arabic changes navigation', (tester) async {
    final repo = BudgetRepository(MemoryVault());
    await tester.pumpWidget(Budget360App(repository: repo));
    await tester.pumpAndSettle();
    await repo.setLocale('ar');
    await tester.pumpAndSettle();
    expect(find.text('نظرة عامة'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    repo.dispose();
  });
}
