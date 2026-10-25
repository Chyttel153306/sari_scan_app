# SariScan production bug audit

Audit date: 25 October 2026 (Asia/Singapore). Project: `D:\flutter projects\SariScan\sari_scan_app`.

**Production readiness: NOT READY for public distribution.** Confirmed client defects were repaired and regression-tested, but the APK still uses debug signing, the repository lacks the backend setup required by the current cloud client, and native iOS and live backend security have not been verified.

The final application source passes Flutter analysis, all **125 tests**, Android release compilation, and APK signature verification. The whole-project formatting check still reports two pre-existing files; the audit did not reformat unrelated code. All 16 Dart files changed or added by this audit pass the formatting check.

## Scope and architecture

Reviewed the accessible source modules under `lib/`, all existing test files and their coverage, `pubspec.yaml`/lockfile, assets and references, Android Gradle/manifests/native activity/resources, iOS Xcode/Swift/plist/configuration, web scaffolding, the launcher generator, and the checked-in SQL migration. Generated build/cache files were not treated as application source.

The architecture remains a Flutter widget application with one `ChangeNotifier`-based `AppStore`. App-private JSON stores accounts, products, sales, stock additions, customer ledgers, and phone preferences. Supabase is optional and exchanges whole snapshots and private product photos. Phone authentication uses `local_auth`; barcode scanning uses `mobile_scanner`; product-photo OCR uses ML Kit; image selection uses `image_picker`; receipts use `pdf`/`printing`. Language selection uses a shared inherited scope and a translation table.

Traced these flows: cold start and local recovery; owner registration/login/rename/logout; first-use and replayable tutorials; inventory creation/edit/stock/archive/delete; barcode lookup/manual scanning; cart/cash/utang checkout; receipts/printing/sharing; customer creation and repayments; reports/charts; settings/theme/language; cloud create/join/push/pull/unlink; photo import/upload/cache/recovery.

No `integration_test/` directory, custom notification implementation, or scheduled background-job implementation was found. `firebase.json` and Android Firebase configuration remain, but the current Dart runtime uses Supabase rather than Firebase messaging or database clients.

Pre-existing uncommitted changes, including language/tutorial work, were preserved. `audit_logs/*.before` capture the pre-audit contents of the relevant existing files so these fixes can be reviewed separately from earlier work.

## A. Critical bugs

No critical exploit or critical-severity defect was established within the accessible, non-production test environment. This is not evidence that the live backend or native runtime has no critical vulnerabilities.

## B. High-severity bugs

References point to the repaired/current source, unless explicitly marked unresolved.

| ID | File and line | Root cause and impact | Fix/status |
|---|---|---|---|
| H01 | `lib/src/store/app_store.dart:1018`; `lib/src/services/snapshot_validation.dart:3` | Cloud/local readers cleared lists while lazily decoding rows. Missing arrays, invalid rows, unsupported versions, duplicate IDs, or negative amounts could silently empty or partially replace records. | Validate the complete snapshot and eagerly decode temporary collections before modifying live state. Preserve existing records/cart on rejection. Five malformed-cloud scenarios were reproduced before fixing. |
| H02 | `lib/src/services/local_storage_service.dart:20`; `lib/src/store/app_store.dart:1316` | A corrupt primary file was preferred over a readable backup. After a load error, later writes could overwrite the unreadable original with an empty/default store. | Recover from readable JSON backups, retain the last complete backup, and block saving/syncing after failed local loading. Invalid data is preserved for recovery. |
| H03 | `lib/src/store/app_store.dart:182`; `lib/src/models/models.dart:72`; `lib/src/models/models.dart:146`; `lib/src/utils/money.dart:2` | Binary floating-point sums made PHP 0.10 + PHP 0.20 exceed PHP 0.30, rejecting exact payment. The same error rejected a final debt repayment or left residual balances. | Round monetary subtotals, cart totals, change, and customer balances to the existing two-decimal peso precision. Cash and repayment regressions pass. |
| H04 | `lib/src/store/app_store.dart:557` | Preparing a replacement/removal deleted the last committed local and remote photo before the product save was validated. Earlier synced snapshots could still reference that remote file. | Photo preparation no longer deletes previously committed images. Existing snapshots retain usable references. Explicit local-cache clearing remains available on unlink. |
| H05 | `lib/src/services/local_storage_service.dart:105` | Photo cleanup accepted any supplied file path, including the store JSON itself. | Restrict deletion to canonical paths inside the managed photo directory and reject symbolic links/outside paths. The regression verifies that unrelated files survive. |
| H06 | `lib/src/store/app_store.dart:653`; `lib/src/store/app_store.dart:713` | Checkout accepted a detached customer object or stock that had become insufficient; repayments could mutate a customer no longer in the store. This could create orphan credit or negative stock. | Validate customer membership and revalidate product/archive/quantity/price/stock state before committing. Fail without changing stock, sales, or ledgers. |
| H07 | `lib/src/store/app_store.dart:819`; `lib/src/store/app_store.dart:1057` | Overlapping sync calls and a delayed download could overwrite edits made after the request started. | Reject overlapping store sync operations and reject downloaded replacements if local revision changed during the download/photo stage. Mocked delayed-download and overlap tests pass. |
| H08 | `lib/src/store/app_store.dart:1057`; `lib/src/store/app_store.dart:947` | Pull/join could report success despite failed local persistence. Unlink cleared in-memory records and pairing before checking whether the clear could be saved. | Propagate each operation's save error and restore the previous records, cart, pairing, timestamps, and warning on the tested failure paths. |
| H09 | `lib/src/store/app_store.dart:246`; `lib/src/store/app_store.dart:263` | Failed account persistence still authenticated the user or changed the owner name in memory. | Authenticate only after a successful account save; restore account/name when saving fails. |
| H10 | `lib/src/store/app_store.dart:640`; `lib/src/store/app_store.dart:678`; `lib/src/screens/checkout_screen.dart:38`; `lib/src/screens/utang_screen.dart:351` | A receipt or successful repayment dismissal could occur before its queued disk write failed. Money/stock/credit changes could appear complete and disappear after restart. | Checkout and repayment now await their exact save result. Failed sales restore stock/cart/sale/credit state, remain at checkout, and show an immediate error. Failed repayments restore the balance and keep the dialog editable. Cash, utang, and repayment failure tests pass. |
| H11 | `android/app/build.gradle.kts:34` | **Unresolved release configuration:** the release build explicitly uses the debug signing configuration. The final APK certificate confirms `CN=Android Debug`. | Configure the owner's production/upload keystore before distribution. No signing identity was invented or replaced. |
| H12 | `lib/src/services/supabase_sync_service.dart:80`; `lib/src/services/supabase_image_service.dart:35`; `supabase/migrations/202608270001_sariscan_schema.sql:148` | **Unresolved repository/backend mismatch:** the client requires `create_store`, `join_store`, `push_snapshot`, `pull_snapshot`, and the private `product-images` bucket/policies. The checked-in migration defines a different, normalized RPC model and does not supply those objects. The referenced `sariscan_supabase_setup.sql` is absent. | Obtain and version the authoritative snapshot-sync migration and storage policies, then test them in staging. No production schema was changed. This finding does not establish that the existing live deployment is missing the objects. |

## C. Medium-severity bugs

| ID | File and line | Root cause | Fix/status |
|---|---|---|---|
| M01 | `lib/src/store/app_store.dart:151`; `lib/src/store/app_store.dart:1316` | A queued write notified disposed notifiers, causing an assertion/error and potentially poisoning subsequent queued work. Save operations also relied on shared mutable error state. | Disposal guard; serialize captured per-operation snapshots and return each operation's own error. Pending-write-after-dispose test passes. |
| M02 | `lib/src/widgets/sales_trend_chart.dart:23` | A selected index from a longer chart was reused after choosing a shorter report period, causing `RangeError`. | Clear selection when its bucket no longer exists or its time boundaries change. Reproduced widget test now passes. |
| M03 | `lib/src/screens/utang_screen.dart:307` | Two save callbacks during dialog dismissal could record two repayments. | Guard immediately and disable repeat submission while awaiting persistence. |
| M04 | `lib/src/screens/products_screen.dart:262` | Two stock-dialog callbacks could record the same delivery twice. Reproduction increased stock from 5 to 11 instead of 8. | Single-submission guard and graceful handling of an invalid/detached product. |
| M05 | `lib/src/screens/login_screen.dart:37`; `lib/src/screens/login_screen.dart:77`; `lib/src/screens/login_screen.dart:126` | Repeated sign-in/recovery/rename actions could launch overlapping phone-authentication requests. | Shared in-progress guards. Duplicate sign-in callbacks are regression-tested. |
| M06 | `lib/src/services/supabase_sync_service.dart:29`; `lib/src/services/supabase_image_service.dart:25` | Cloud authentication/RPCs and photo transfers had no application-level deadline, allowing a stalled connection to leave loading state pending. | Configurable 20-second deadlines and owned HTTP-client cleanup. Stalled cloud-auth and legacy-image requests are tested with mocked transports. A timeout does not cancel a server-side write already in progress. |
| M07 | `lib/src/store/app_store.dart:205`; `lib/src/store/app_store.dart:216` | Startup awaited remote image downloads before `runApp`; restored local image paths were not saved afterwards. | Restore photos in the background after local loading and persist changed cache paths. A delayed-photo test proves initialization finishes before the network response. |
| M08 | `lib/src/services/supabase_sync_service.dart:89`; `lib/src/services/supabase_sync_service.dart:135` | Unexpected RPC responses could be stringified into sync codes such as `null`; malformed snapshot envelopes were treated as ordinary absence. | Validate response types and non-empty codes; distinguish malformed data from a missing store. Null/numeric/empty-code response tests pass. |
| M09 | `lib/src/screens/products_screen.dart:669` | Photo-picker permission/platform failures escaped the async handler. The handler could also continue after its route was removed. | Catch failures and check mounting before launching/continuing the picker. Defensive code-path fix; actual native permission behavior remains a manual check. |
| M10 | `lib/src/store/app_store.dart:263` | Renaming changed the registered name but left `currentUserName` stale in the active shell/audit identity. | Update the active identity after successful persistence. Reproduced regression passes. |
| M11 | `lib/src/store/app_store.dart:486` | Adding to the maximum signed stock count overflowed into a negative value. | Reject overflow before changing stock or inserting an audit entry. Boundary test passes. |
| M12 | `ios/Runner.xcodeproj/project.pbxproj:363`; `ios/Podfile:1`; `ios/Flutter/Debug.xcconfig:1`; `ios/Flutter/Release.xcconfig:1` | The project declared iOS 13 while pinned OCR dependency 0.16.0 requires iOS 15.5; CocoaPods configuration/include plumbing was absent. | With explicit user approval, raise project targets to 15.5 and add CocoaPods integration. Verified by source/configuration inspection only; macOS/Xcode/CocoaPods compilation is still required. |

The iOS requirement is documented by the package's [versioned publisher documentation](https://pub.dev/packages/google_mlkit_text_recognition/versions/0.16.0) and confirmed in the locally installed podspec (`s.ios.deployment_target = '15.5'`).

## D. Low-severity bugs

| ID | File and line | Root cause | Fix/status |
|---|---|---|---|
| L01 | `lib/src/screens/checkout_screen.dart:244`; `lib/src/widgets/add_customer_dialog.dart:52`; stock/payment validators in `products_screen.dart` and `utang_screen.dart` | Some existing translated messages were still rendered directly in English. | Route those subtitles, validation messages, and repayment errors through the existing translation lookup. |
| L02 | `lib/main.dart:1`; ignored `build/ui_preview_test.dart` | The required whole-tree formatter check reports pre-existing formatting differences. | Deliberately unchanged under the instruction not to reformat unrelated files. The checker used `--output=none`; its word `Changed` means it would reformat, not that files were written. All audit-modified Dart files pass separately. |

## E. Fixes applied and verification approach

No application architecture, API contract, database structure, asset design, normal navigation, or existing feature was replaced. The synchronous store methods remain available; UI financial confirmations use additional durable methods. Normal checkout stays on the same screen while its existing button displays `Saving...`; back navigation is blocked only during that commit. Exceptions leave the user with an editable form and the restored transaction state.

Validation, backup recovery, precise currency rounding, persistence rollback, safe photo retention, local-edit protection, lifecycle guards, duplicate-submit prevention, bounded network requests, background photo recovery, chart selection reset, owner identity updates, stock overflow handling, and approved iOS configuration changes were applied.

There are **36 new tests** in three audit test files, for **125 total tests** including the original 89. Before their corresponding fixes, 24 regression cases were actually run and failed; the rest add positive/boundary/network/large-screen coverage. Failed attempts and successful reruns are retained in the logs rather than represented as successful initial runs.

A separate review pass compared modified files against their `.before` copies, followed the callers of new durable methods, checked persistence/sync rollback and photo-path boundaries, and checked native configuration. That review found the stale identity, stock overflow, and premature financial confirmations, which were then reproduced and fixed. It is a second review pass by the same agent, not an external security review.

## F. Files modified by this audit

Existing application files:

- `lib/src/store/app_store.dart`
- `lib/src/models/models.dart`
- `lib/src/services/local_storage_service.dart`
- `lib/src/services/supabase_sync_service.dart`
- `lib/src/services/supabase_image_service.dart`
- `lib/src/screens/checkout_screen.dart`
- `lib/src/screens/login_screen.dart`
- `lib/src/screens/products_screen.dart`
- `lib/src/screens/utang_screen.dart`
- `lib/src/widgets/sales_trend_chart.dart`
- `lib/src/widgets/add_customer_dialog.dart`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Flutter/Debug.xcconfig`
- `ios/Flutter/Release.xcconfig`

New application/configuration/test files:

- `lib/src/services/snapshot_validation.dart`
- `lib/src/utils/money.dart`
- `ios/Podfile`
- `test/audit_regression_test.dart`
- `test/audit_network_test.dart`
- `test/audit_ui_test.dart`

Documentation/evidence: this report and `audit_logs/`. Other dirty/untracked files visible in Git were already present when this audit began. Temporary Dart edit scripts were removed.

## G. Tests executed and results

All commands ran from the Flutter root using the installed SDK's full executable path because Flutter/Dart are not on PATH.

| Command/check | Final result | Evidence |
|---|---|---|
| `flutter doctor -v` | Completed, exit 0; reported issues in three categories. Flutter/Dart absent from PATH; Android cmdline-tools missing and licenses unknown; Visual Studio absent. | `audit_logs/doctor.log` |
| `flutter pub get` | Passed, exit 0. No dependency upgrade was applied. | `audit_logs/pub_get.log` |
| `flutter pub outdated` | Completed. Six direct dependencies have newer versions; dev `image` also has a newer version. Output reports 26 upgradable locked dependencies and two constraints older than a resolvable version. | `audit_logs/outdated.log` |
| `dart format --output=none --set-exit-if-changed .` | Exit 1 for the two unchanged, pre-existing files listed in L02. | `audit_logs/format_final.log` |
| Same formatter check on all 16 audit-modified Dart files | Passed, exit 0; zero changes needed. | `audit_logs/format_modified.log` |
| `flutter analyze` | Passed, exit 0; no issues found. | `audit_logs/analyze_final.log` |
| `flutter test` | Passed, exit 0; **125 tests**. Initial unmodified suite also ran successfully with 89 tests. | `audit_logs/test_final.log`, `audit_logs/test_initial.log` |
| New audit tests | All pass, including full-disk failures, malformed snapshots, delayed sync/auth/photo requests, disposed stores, duplicate callbacks, decimal balances, and overflow. | Three `test/audit_*_test.dart` files and regression logs |
| UI responsiveness | Widget checks cover 320/390-pixel phones and 900/1200-pixel large displays, including enlarged text. These are simulated widget surfaces, not native device certification. | `test/modern_ui_test.dart`, `test/language_test.dart`, `test/product_customer_ui_test.dart`, `audit_logs/large_screen_tests.log` |
| `flutter build apk --release` | Passed on final application source; universal APK reported as **105.4 MB**. Build was also run before fixes. | `audit_logs/apk_final.log`, `audit_logs/apk_initial.log` |
| Android APK signature verification | Passed after build completion; v2 signature valid. Certificate is **Android Debug**, which is a release blocker. | `audit_logs/signature_final.log` |
| APK permission inspection | Inspected merged INTERNET, network-state, camera, biometric/fingerprint, and non-exported-receiver permissions. | `audit_logs/apk_permissions.log` |
| `git diff --check` | Passed. | `audit_logs/diff_check.log` |

Final artifact: `build/app/outputs/flutter-apk/app-release.apk`. Do not distribute it as a production-signed release.

An extra signature check was initially run while a build was updating the output APK and reported a digest mismatch. Once the build had completed, repeated verification succeeded and original/copied APK hashes matched. The definitive final check was explicitly sequenced after the final build. That transient read of an in-progress artifact is not reported as an application signing defect.

The helper PowerShell script could not be launched under this machine's script execution policy; all requested checks were then executed directly. An intermediate result-summary update also encountered a PowerShell array-wrapping issue; the raw checks still ran, and `final_results.json` was corrected from their recorded outcomes. These were audit-tooling problems, not app test results.

## H. Tests not executed and why

- **iOS build, CocoaPods installation, simulator, XCTest and device checks:** this host is Windows; macOS/Xcode/CocoaPods are unavailable. The user-authorized 15.5 configuration is not claimed to have compiled.
- **Native integration suite:** no `integration_test/` suite exists. The connected Android phone was not overwritten, reset, signed into, or used to modify existing app data.
- **Live Supabase create/join/push/pull, cross-account denial tests, bucket policies and database migrations:** no approved staging backend/schema was supplied. SQL and RPC compatibility were inspected locally; network regressions used mock clients. No production records, auth users, photos, or schema were changed.
- **Actual biometric prompts, denied/permanently denied permissions, camera/OCR/photo-picker process death, printing/share targets, background/resume and process-kill durability:** these require native device interaction. Mocked/widget tests do not establish those platform behaviors.
- **Sustained frame-time/memory/battery profiling:** no profile-mode capture with a representative real catalog/device workload was performed. Existing large-catalog rebuild/scroll tests did run.
- **Web/desktop certification:** the app is documented as Android-first and uses native/file APIs; those targets were not claimed as supported release targets by this audit.
- **Launcher-icon regeneration:** intentionally not run because it rewrites approved assets rather than verifying application behavior.

## I. Remaining risks and release requirements

1. **Production signing is missing (H11).** Use an owner-controlled signing/upload identity. Default example application/bundle identifiers also need an explicit release decision; changing them silently would change installation/data identity.
2. **Backend reproducibility and security remain unverified (H12).** Version the authoritative cloud RPC/bucket migration; verify anonymous sign-in configuration, membership enforcement, cross-store read/write denial, storage isolation, code entropy/rate limits, and recovery in staging.
3. **Manual whole-snapshot sync remains last-writer-wins across different phones.** This audit protects the reproduced same-phone races; it does not introduce server-side compare-and-swap/version conflicts or merge concurrent edits from separate phones.
4. **Timed-out remote writes can still complete on the server.** Client deadlines release loading state; they do not guarantee cancellation or idempotency. A staging backend must establish retry semantics.
5. **Inventory/catalog/customer creation still uses the existing write-behind model.** The critical checkout and repayment confirmations now await persistence. Low-storage/process-kill behavior for other mutations remains a device-verification item; keep durable backups and monitor the existing storage-error indication.
6. **Strictly invalid snapshots are rejected rather than repaired automatically.** Existing malformed/unsupported data may require deliberate recovery. It is not silently reset or overwritten.
7. **Previous photos are retained for snapshot safety.** Replaced/unreferenced files can consume storage until a safe retention/garbage-collection policy is designed. Unlink still clears the managed local cache.
8. **Native iOS and Android failure/lifecycle scenarios still need execution.** In particular, photo-picker activity death/recovery, camera permission changes, biometric fallback, and real printer/share behavior were not certified.
9. **Privacy depends on app-private OS storage, device security and live RLS.** No app-level database encryption or automatic background relock was added; verify backup/transfer, token storage, screenshots and shared-device requirements against the actual threat model. Legacy photo downloads accept remote URLs; hostile/oversized content was not fuzzed.
10. **Dependency maintenance remains work.** Current pinned versions build and pass the available tests; outdated does not by itself prove vulnerability. No blanket upgrade was applied. The build also warns about future Flutter/AGP built-in-Kotlin compatibility. Recheck newer packages in a separate tested upgrade.
11. **Two pre-existing formatting differences remain (L02).** They do not explain runtime bugs, but the exact whole-tree formatting gate is not green.

The hardcoded Supabase value is a publishable key, not a service-role secret. Its presence in a mobile binary is expected; protection depends on authenticated policies, as explained in [Supabase's API-key documentation](https://supabase.com/docs/guides/getting-started/api-keys). A targeted source scan did not find a service-role/private-key signature in the reviewed source patterns; that is not a full secret-history scan.

## J. Production readiness

**NOT READY for public production distribution.**

Required before release: configure production signing; provide and test the current backend schema/policies in staging; build and test iOS on macOS; execute native Android failure/lifecycle/payment/printing checks; and resolve the operational risks above against the store's real usage and backup requirements.

The accessible client modules have been reviewed and the reported fixes verified to the stated scope. Successful tests and builds do not establish that the application is 100% bug-free or that untested native/backend behavior is safe.
