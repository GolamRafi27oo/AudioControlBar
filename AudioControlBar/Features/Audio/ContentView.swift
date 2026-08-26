import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioManager.shared
    @State private var page: Page = .audio

    private enum Page { case audio, settings }

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 0) {
                header
                Group {
                    if page == .audio {
                        audioPage.transition(.opacity)
                    } else {
                        SettingsView().transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
        }
        .frame(width: 360, height: 500)
        .animation(.easeOut(duration: 0.16), value: page)
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(Color.accentColor.gradient)
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(page == .audio ? "Audio Control" : "Settings")
                    .font(.system(size: 14, weight: .semibold))
                Text(page == .audio ? statusSummary : "Personalize your menu bar app")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            GlassIconButton(systemName: page == .audio ? "gearshape.fill" : "xmark", help: page == .audio ? "Settings" : "Close settings") {
                page = page == .audio ? .settings : .audio
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, 11)
        .padding(.bottom, 9)
    }

    private var audioPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                AudioSectionView(
                    title: "Output", subtitle: "Sound playback", systemIcon: "speaker.wave.3.fill", iconColor: .blue,
                    devices: audio.outputDevices, selectedDevice: audio.selectedOutputDevice, volume: audio.outputVolume, muted: audio.outputMuted,
                    onSelectDevice: { audio.setDefaultDevice($0, isInput: false) },
                    onVolumeChange: { audio.setVolume($0, isInput: false) },
                    onMuteToggle: { audio.toggleMute(isInput: false) }
                )
                AudioSectionView(
                    title: "Input", subtitle: "Microphone level", systemIcon: "mic.fill", iconColor: .mint,
                    devices: audio.inputDevices, selectedDevice: audio.selectedInputDevice, volume: audio.inputVolume, muted: audio.inputMuted,
                    onSelectDevice: { audio.setDefaultDevice($0, isInput: true) },
                    onVolumeChange: { audio.setVolume($0, isInput: true) },
                    onMuteToggle: { audio.toggleMute(isInput: true) }
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { audio.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh devices")
            Spacer()
            Button {
                guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else { return }
                NSWorkspace.shared.open(url)
            } label: { Label("Sound Settings", systemImage: "slider.horizontal.3") }
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .help("Quit AudioControlBar")
        }
        .font(.system(size: 10.5, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .frame(height: 36)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), prominence: .clear)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var statusSummary: String {
        "Playing through \(audio.selectedOutputDevice?.name ?? "No output")"
    }
}

struct AudioSectionView: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    let iconColor: Color
    let devices: [AudioDevice]
    let selectedDevice: AudioDevice?
    let volume: Float
    let muted: Bool
    let onSelectDevice: (AudioDevice) -> Void
    let onVolumeChange: (Float) -> Void
    let onMuteToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: systemIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 27, height: 27)
                    .background(iconColor.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 9.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(muted ? "Muted" : "\(Int(volume * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(muted ? .red : .secondary)
                    .contentTransition(.numericText())
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.primary.opacity(0.055), in: Capsule())
            }
            deviceList
            volumeControl
        }
        .padding(11)
        .glassCard(tint: iconColor.opacity(0.05))
    }

    private var deviceList: some View {
        VStack(spacing: 1) {
            if devices.isEmpty {
                VStack(spacing: 3) {
                    Image(systemName: systemIcon).font(.system(size: 15)).foregroundStyle(.secondary)
                    Text("No \(title) Devices").font(.system(size: 10.5, weight: .medium))
                    Text("Connect a device, then refresh.").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).frame(height: 58)
            } else {
                ForEach(devices) { device in
                    DeviceRowView(device: device, isSelected: selectedDevice?.id == device.id, accent: iconColor) { onSelectDevice(device) }
                }
            }
        }
        .padding(3)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Button(action: onMuteToggle) {
                Image(systemName: muteIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(muted ? .red : iconColor)
                    .frame(width: 26, height: 26)
                    .background((muted ? Color.red : iconColor).opacity(0.11), in: Circle())
            }
            .buttonStyle(.plain)
            .help(muted ? "Unmute \(title.lowercased())" : "Mute \(title.lowercased())")
            Slider(value: Binding(get: { Double(volume) }, set: { onVolumeChange(Float($0)) }), in: 0...1)
                .tint(muted ? .red : iconColor)
                .disabled(muted)
            Image(systemName: title == "Output" ? "speaker.wave.3.fill" : "waveform")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary).frame(width: 16)
        }
    }

    private var muteIcon: String {
        title == "Output" ? (muted ? "speaker.slash.fill" : "speaker.wave.1.fill") : (muted ? "mic.slash.fill" : "mic.fill")
    }
}

struct DeviceRowView: View {
    let device: AudioDevice
    let isSelected: Bool
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Image(systemName: transportIcon(device.transportType))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .frame(width: 22, height: 22)
                    .background(isSelected ? accent.opacity(0.14) : .clear, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name).font(.system(size: 11, weight: isSelected ? .semibold : .regular)).foregroundStyle(.primary).lineLimit(1)
                    Text(device.transportType).font(.system(size: 8.5)).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 7).frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(isSelected ? accent.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private func transportIcon(_ type: String) -> String {
        switch type {
        case "Bluetooth": return "wave.3.right"
        case "USB": return "cable.connector"
        case "HDMI": return "display"
        case "Built-in": return "macbook"
        case "Virtual": return "square.stack.3d.up"
        case "Thunderbolt": return "bolt.horizontal.fill"
        default: return "headphones"
        }
    }
}
