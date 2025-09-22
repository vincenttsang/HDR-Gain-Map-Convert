# Localisation Setup

This iGainMapHDR app now supports internationalization (i18n) with the following languages:

## Supported Languages

1. **English (Base)** - Base localisation
2. **English (UK)** - British English variant  
3. **Simplified Chinese (zh-Hans)** - 简体中文
4. **Traditional Chinese (zh-Hant)** - 繁體中文
5. **Japanese (ja)** - 日本語
6. **Cantonese (zh-HK)** - 廣東話 (Hong Kong)

## Localisation Files

The localisation files are organized in the following structure:

```
iGainMapHDR/
├── Base.lproj/
│   ├── Localizable.strings
│   └── InfoPlist.strings
├── en-GB.lproj/
│   ├── Localizable.strings
│   └── InfoPlist.strings
├── zh-Hans.lproj/
│   ├── Localizable.strings
│   └── InfoPlist.strings
├── zh-Hant.lproj/
│   ├── Localizable.strings
│   └── InfoPlist.strings
├── ja.lproj/
│   ├── Localizable.strings
│   └── InfoPlist.strings
└── zh-HK.lproj/
    ├── Localizable.strings
    └── InfoPlist.strings
```

## Key Features Localised

- Tab labels (Single File, Multiple Files)
- Settings panel headers and options
- Button labels and UI text
- File dialog titles
- Notification messages
- Console/debug messages
- App display name

## How to Test

1. Build and run the app in Xcode
2. Change your system language to test different localisations
3. Alternatively, you can test in Xcode by:
   - Going to Product → Scheme → Edit Scheme
   - Under "Run" → "Options" → "App Language"
   - Select the language you want to test

## Adding New Languages

To add support for additional languages:

1. Create a new `.lproj` directory (e.g., `fr.lproj` for French)
2. Copy `Localizable.strings` and `InfoPlist.strings` from Base.lproj
3. Translate all the strings in the new files
4. Update the `knownRegions` in the Xcode project file
5. Rebuild the app

## Technical Implementation

- All user-facing strings use `NSLocalizedString()` for automatic localisation
- String formatting is handled with proper localisation support
- The app respects the user's system language preferences
- Fallback to Base localisation if a specific language is unavailable
