# Warning 
Don't add any feature which will require mic permission.

# AudioControlBar

A native macOS menu bar app for switching audio input/output devices and controlling volume, built for Apple Silicon.

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon Mac (M1/M2/M3/M4/M5)
- Xcode 26+ (to build the native Liquid Glass interface)

## Build & Install

### 1. Open Terminal in the project folder

```bash
cd /path/to/AudioControlBar
chmod +x build.sh
./build.sh
```

The script will:
- Build the Release app for arm64
- Ad-hoc code sign it
- Create a `.dmg` installer
- Optionally launch the app immediately

### 2. Install from DMG

Double-click `AudioControlBar.dmg`, drag the app to Applications, and launch it.

## Download

⬇️ [Download AudioControlBar for macOS](./AudioControlBar.dmg)

### 3. Or open directly in Xcode

Double-click `AudioControlBar.xcodeproj` → Product → Run (⌘R)

## Permissions

AudioControlBar uses Core Audio device controls and does not request microphone access.

## Automatic Updates

AudioControlBar uses Sparkle 2 to check for signed updates automatically. Users can also
select **Settings → Check Now**. The update feed is [`appcast.xml`](./appcast.xml).

To publish a release:

1. Increase `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode target.
2. Build, Developer ID sign, and notarize `AudioControlBar.dmg`.
3. Create a GitHub release tagged `v<MARKETING_VERSION>` and attach the DMG without renaming it.
4. Run Sparkle's `generate_appcast` against the DMG using the matching GitHub release URL.
5. Commit and push the updated `appcast.xml` to `main`.

The Sparkle private EdDSA key remains in the release maintainer's Keychain. Back it up securely;
never commit it to this repository.


## File Structure

```
AudioControlBar/
├── App/                       # App entry point and menu bar lifecycle
├── Core/Audio/                # Core Audio device and volume services
├── DesignSystem/              # Liquid Glass components and styling
├── Features/
│   ├── Audio/                 # Main audio controls
│   └── Settings/              # App settings
└── Resources/                 # Assets, Info.plist, and entitlements
```

## Troubleshooting

**App doesn't appear in menu bar**: Make sure Xcode built successfully and that `LSUIElement` is `true` in Info.plist (hides Dock icon, shows menu bar icon instead).

**"AudioControlBar can't be opened because it's from an unidentified developer"**:
Right-click the app → Open → Open anyway.

**No devices listed**: Reconnect the device and select Refresh. Confirm that macOS recognizes it in System Settings → Sound.

**Launch at Login not working**: This requires macOS 13+. The toggle uses `SMAppService.mainApp`.
