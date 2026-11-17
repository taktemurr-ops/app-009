# APP-009 — Bütçe 360 / Budget 360

An offline-first Turkish/English/Arabic Flutter household budget planner for Android and iOS. No bank account linking, remote sync, artificial financial advice, payment execution, or covert data access.

## Implemented product

- Local income and expense tracking with explicit dates, categories, member labels, descriptions and search.
- Currency selection (TRY / USD / EUR) **before** financial records exist, currency-safe minor-unit math and Unicode Arabic/Persian/Latin number parsing.
- Per-category monthly budgets, over-limit signals, income/expense balance and trend summaries.
- Savings goals with contributions and overfunding protection; contributions do not double-count journal expenses.
- Monthly recurring rule planner with due-date handling for February, explicitly triggered posting and duplicate prevention.
- Local household member labels, task/checklist and personal finance journal.
- Six-month reports, largest-spend identification, deterministic coaching and savings challenges.
- Offline mini-academy, editable budget-template calculator, planning tools and private data management.
- Secure OS-backed local persistence, validated JSON export/import, user-confirmed erase, bilingual + Arabic RTL UI.
- Unit and widget tests, Android GitHub Actions debug APK build pipeline.

## Development

```sh
flutter create --project-name butce_360 --platforms=android,ios .
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

**Not a completed store release**: device QA, production signing, iOS Xcode compilation, regulatory/privacy declarations, and real payment/ads/IAP configuration are separate gates. There is **no paid unlock, ad or live IAP** in this offline candidate. See `docs/release-gates.md`.
