import SwiftUI
import ServiceManagement
struct SettingsView: View {
    @AppStorage("showVolumeInMenuBar") private var showVolumeInMenuBar = false
    @AppStorage("showDeviceNameInMenuBar") private var showDeviceNameInMenuBar = false
    @AppStorage("startupDelay") private var startupDelay = 0.0
    @AppStorage("theme") private var theme = "system"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Launch at Login
            SettingsSectionHeader(title: "General")

            VStack(spacing: 0) {
                LaunchAtLoginToggleRow()
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // About
            SettingsSectionHeader(title: "About")

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AudioControlBar")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")) · macOS Silicon")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
    }
}

// MARK: - Launch At Login Row (uses ServiceManagement)
struct LaunchAtLoginToggleRow: View {
    @State private var isEnabled: Bool = false

    var body: some View {
        HStack {
            Image(systemName: "clock.arrow.2.circlepath")
                .foregroundColor(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Launch at Login")
                    .font(.system(size: 12))
                Text("Start AudioControlBar when you log in")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isEnabled) { newValue in
                    setLaunchAtLogin(enabled: newValue)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { isEnabled = getLaunchAtLoginEnabled() }
    }

    private func getLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }
}

// MARK: - Reusable Toggle Row
struct ToggleSettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Section Header
struct SettingsSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .padding(.top, 4)
    }
}
