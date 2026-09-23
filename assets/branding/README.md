# SariScan branding

The charcoal storefront and cyan scanning beam come from the logo supplied by the user. The built-in imagegen tool prepared a transparent PNG from the checkerboard reference. This is a cleaned rendition, not the original source file.

- `sariscan_logo_source.png`: transparent master, with symbol and wordmark.
- `sariscan_logo.png`: trimmed complete logo for sign-in and receipts.
- `sariscan_symbol.png`: storefront/scanner for small UI marks and launcher icons.

Run `dart run tool/generate_launcher_icons.dart` from the project root to reproduce Android, iOS, web, splash, and bundled artwork sizes. The script preserves the artwork colors; launcher backgrounds are white, iOS app icons contain no alpha, and adaptive/maskable icons have safe margins. `BrandMark` supplies a light backing for readability in dark themes.

Imagegen edit prompt:

> Edit target: the USER-UPLOADED SariScan logo with charcoal storefront awning, cyan awning panels, cyan glowing horizontal scan line between dark scan brackets, and dark 'SariScan' wordmark on a gray-and-white checkerboard. The other recent image (white storefront on green square) is an OLD LOGO to ignore completely. Clean the USER logo for production app use: remove ALL gray/white checkerboard and make background genuinely transparent alpha, including inside storefront and letters. Faithfully preserve the exact geometry, charcoal gray strokes, turquoise/cyan panels, scanner glow, proportions and SariScan text/capitalization in user's reference. Do not redesign, recolor, add elements or substitute the old green logo. Produce high-resolution crisp logo with the complete storefront/scanner above the complete SariScan wordmark in the same arrangement, centered, tight but safe transparent margins. No checkerboard drawn in image, no background, no mockup. Save transparent PNG.
