# Bundled Google Fonts

The app loads these ten font families from Flutter assets, with runtime font
downloads disabled. All 89 variants exposed by google_fonts 8.2.1 are included
(9,957,656 bytes before compression). The manifest records each original file's
SHA-256 and length. Fonts are unmodified; each family's OFL license is included
and registered in the app license registry.

Verify without network access:

```
node scripts/bundle_google_fonts.cjs --check
flutter test test/core/bundled_fonts_test.dart --dart-define-from-file=.env.local.json
```

After an approved google_fonts upgrade, run `node scripts/bundle_google_fonts.cjs`.
It downloads missing fonts with hash verification and prints an apply_patch patch
for licenses and the manifest. Apply that patch, review it, and rerun both checks.
Do not enable runtime fetching to hide missing assets.

System fallback still supplies scripts not supported by these font families.
This does not guarantee every glyph on every Android, iOS or web platform.
