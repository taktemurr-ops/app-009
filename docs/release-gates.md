# APP-009 acceptance gates

The current package is a **working offline product candidate**, not a fully released commercial application.

| Area | Gate |
| --- | --- |
| Functional product | Dashboard, expenses, income, budgets, saving goals, recurring rules, household labels, checklist, journal, 6-month reporting, offline tips, education, backup and settings must all work. |
| Integrity | All amounts integer cents; robust local number parsing; cross-month de-duplication; strict import validation; failed storage writes preserve journal. |
| Localization | Turkish, English, Arabic; RTL and localized date / currency display on supported devices. |
| Privacy | Storage security review; clipboard plaintext warning; explicit wipe/import consent. |
| Flutter QA | Analyze and unit/widget tests succeed in Actions on current source commit. |
| Android | Debug build succeeds; release AAB must later be signed using owner credentials; physical Android device smoke tested. |
| iOS | Project must compile on macOS/Xcode with owner Apple certificates; physical iPhone device smoke tested. |
| Monetization | No real ads or IAP enabled. Owner must provide legitimate AdMob/Play/App Store setup before adding and validating monetization; no placeholder claims. |
| Stores | Final privacy/data-safety declarations, screenshots, accessibility, locales, age rating, license, publication policy review. |

Only count as **final delivered** after all relevant store and device gates pass. Debug APK artifact and GitHub CI alone are not publication proof.
