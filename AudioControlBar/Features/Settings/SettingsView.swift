import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SettingsGroup(title: "General") { LaunchAtLoginToggleRow() }
                SettingsGroup(title: "About") {
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.gradient)
                            Image(systemName: "waveform").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        }
                        .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AudioControlBar").font(.system(size: 12, weight: .semibold))
                            Text(versionText).font(.system(size: 9.5)).foregroundStyle(.secondary)
                            Text("A focused audio controller for macOS").font(.system(size: 9.5)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(spacing: 0) { content }.glassCard()
        }
    }
}

private struct LaunchAtLoginToggleRow: View {
    @State private var isEnabled = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.orange)
                    .frame(width: 28, height: 28).background(Color.orange.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login").font(.system(size: 11.5, weight: .medium))
                    Text("Start automatically when you log in").font(.system(size: 9.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .onChange(of: isEnabled) { newValue in setLaunchAtLogin(enabled: newValue) }
            }
            .padding(10)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10)).foregroundStyle(.red)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .onAppear { isEnabled = SMAppService.mainApp.status == .enabled }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t update login settings."
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
