# Budget 360 privacy and storage

- Entirely offline. No analytics events, accounts, advertising SDKs, external AI calls, cloud sync, or bank connections.
- Budget journals, income/expenses, recurring tasks, household labels and backups live in a single Flutter Secure Storage record; platforms use their OS-backed key-protection facilities.
- Full JSON export is **plaintext** and the user has to explicitly confirm copying it to the OS clipboard; the clipboard can be readable by other apps. Keep the backup only in a secure location.
- JSON import is explicitly user-confirmed and validates all records before replacing storage; a failed write leaves in-memory records unchanged.
- All-data deletion removes the secure-storage key after an explicit confirmation. Uninstall/backups may behave differently by OS; verify with production devices.
- Household members are **local labels only**, not remote users. No shared multi-device access or live collaboration.
- Recurring transactions only post to the offline journal when the user taps Record Due. There is no bank payment or debit integration.
- Currency can be set before any financial records; amounts are not silently converted or re-labeled after entries exist.
- The AI coach is not a generative-model integration. It is deterministic, device-local advice rules.

No server stores any user records in this build. Before release, perform independent platform-level security and privacy assessment and verify all store declarations.
