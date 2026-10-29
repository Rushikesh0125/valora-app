# Valora landing page

Responsive marketing page based on the approved kitchen/cream/sage design.

## Run locally

Requires Node.js. Install with `npm install`, then `npm run dev -- --host 127.0.0.1 --port 4175 --strictPort`.

`npm run build` creates the production output in `dist/client` and preserves the starter's Sites packaging. Nothing is deployed automatically.

## Implemented

- Staggered headline and phone entrances; separate transparent phone layers.
- One-time section reveals, photo settling, modest desktop scroll depth, button hover/press feedback.
- Responsive layouts, keyboard focus, native scrolling and reduced-motion support.
- APK download and a Google Play coming-soon dialog.
- Expandable meal/pantry information through the editorial links.

The APK is the existing **debug preview**, copied from `../mobile/build/app/outputs/flutter-apk/app-debug.apk` into `public/downloads/valora-android-preview.apk`. APKs are excluded from version control. Restore that file from a current preview build before running or packaging a fresh checkout. There is no published Play Store URL or live AI/ordering integration.

Images are generated assets inspired by the selected mock. Phone screens are illustrative marketing renders. Fonts are bundled from the Flutter app with their open font licences. `scripts/optimize-images.py` encodes the original PNGs into WebP using Pillow; it does not alter their geometry. The page serves the WebP files (~2 MB total), with original PNGs retained for future editing.

## Validation

Automated tests were not added or run for this task. Production compilation was run successfully. Browser checks covered desktop, 390 px and 320 px layouts, the Play Store dialog, expanded editorial information and emulated reduced motion. APK file presence and packaged byte count were checked; installation on a phone was not performed.
