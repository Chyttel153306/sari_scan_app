# SariScan

SariScan is an Android-first mobile point-of-sale app for sari-sari stores. The
application is written in Dart with Flutter and includes:

- owner-name login protected by the phone's fingerprint, face, PIN, pattern, or password
- offline, device-only account and private phone storage
- optional product photos stored privately on the phone
- product, price, barcode, and stock management
- live camera barcode scanning plus manual barcode entry
- cash checkout, automatic change, and digital receipts
- utang checkout, customer ledgers, and partial/full payments
- daily, weekly, monthly, and annual sales summaries
- transaction history and top-product reporting
- native PDF receipt printing and sharing

## Run locally

```sh
flutter pub get
flutter run
```

No server or internet connection is required while using the app. On first use,
enter the store owner's name and approve the phone security prompt. SariScan
does not create demo products, customers, or sales. Records appear only after
the owner adds them, and they are saved to app-private storage on the phone.
Android/iOS removes that data when the app is uninstalled or its storage is
cleared, so back up important records separately.

## Run on an Android phone over USB

1. Enable Developer options and USB debugging on the phone.
2. Connect the phone and accept its RSA debugging prompt.
3. Confirm it appears with `flutter devices`.
4. Run `flutter run -d DEVICE_ID`.

Android asks for camera permission the first time the scanner opens. Printing
and sharing use the phone's installed print services and share targets.
