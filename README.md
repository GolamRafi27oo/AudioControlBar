# AudioControlBar

A native macOS menu bar app for controlling audio input/output devices, volume, and input level — built for Apple Silicon.

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon Mac (M1/M2/M3/M4/m5)
- Xcode 15+ (to build)

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

On first launch, macOS will ask for **Microphone** permission — this is required for the live input level meter. You can grant it in:

> System Settings → Privacy & Security → Microphone → AudioControlBar ✓


## File Structure

```
AudioControlBar/
├── AudioControlBarApp.swift   # @main SwiftUI entry point
├── AppDelegate.swift          # NSStatusItem + popover management
├── AudioManager.swift         # CoreAudio device list, volume, VU meter
├── ContentView.swift          # Main popover UI (output + input sections)
├── SettingsView.swift         # Settings panel with launch-at-login
├── Info.plist                 # LSUIElement = true (hides from Dock)
├── AudioControlBar.entitlements
└── Assets.xcassets/
```

## Troubleshooting

**App doesn't appear in menu bar**: Make sure Xcode built successfully and that `LSUIElement` is `true` in Info.plist (hides Dock icon, shows menu bar icon instead).

**"AudioControlBar can't be opened because it's from an unidentified developer"**:
Right-click the app → Open → Open anyway.

**No devices listed**: Grant microphone permission in System Settings → Privacy & Security.

**Launch at Login not working**: This requires macOS 13+. The toggle uses `SMAppService.mainApp`.