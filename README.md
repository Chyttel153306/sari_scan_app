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

The interface uses emerald accents, rounded product cards, and a consistent
layout across login, POS, inventory, checkout, utang, reports, and receipts.
Plus Jakarta Sans and Space Grotesk are bundled for offline use. Utang filters
show all, pending, or paid customers, and reports use the store's actual records.

Use a product's three-dot menu to edit, archive, restore, or delete it. Deleting
removes the product from inventory and the current cart while keeping past
receipts and customer balances.

Utang checkout includes an **Add customer** button. New customers are selected
automatically so you can finish the sale without leaving checkout. Product
prices use a consistent font size. Inventory and POS use compact, equal-sized cards;
long prices scroll horizontally within their price field. The white three-dot
button opens product actions, and the circular pencil button opens editing.

Sales reports include cash and utang purchases through the current time.
Weeks start on Monday; monthly bars show their exact day ranges. The chart
starts at zero, and tapping a bar shows its full peso amount. Swipe horizontally
to see every period on a small screen. Utang repayments do not count as new sales.

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

## Share a store between phones

In Settings > Sync, create a code on the phone that holds the store. Creating
the code uploads existing records and photos, including photos added before
linking. Enter that code on another phone to download the store and cache its
photos locally.

For later changes, choose **Upload changes** on the source phone, then
**Download latest** on the other phone. Uploading retries pending photos; a
photo failure shows a warning while the records still sync. Downloads replace
the receiving phone's store records, so upload any changes you need first.

**Unlink this phone** clears its local store records and cached product photos.
The cloud store remains saved, and entering the same code restores it. Keep the
code and upload changes before unlinking; changes saved only on the phone will
be lost. The phone's owner login is retained.

## Run on an Android phone over USB

1. Enable Developer options and USB debugging on the phone.
2. Connect the phone and accept its RSA debugging prompt.
3. Confirm it appears with `flutter devices`.
4. Run `flutter run -d DEVICE_ID`.

Android asks for camera permission the first time the scanner opens. Printing
and sharing use the phone's installed print services and share targets.

## Launcher branding

Android, iOS, and web launcher icons use the same emerald gradient and white
storefront mark as the SariScan login screen. Regenerate them with
`flutter test tool/generate_launcher_icons.dart`. The generator also writes the
master image to `assets/branding/sariscan_logo.png`.
