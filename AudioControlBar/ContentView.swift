import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioManager.shared
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
                Text("Audio Control")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if showSettings {
                SettingsView()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // OUTPUT SECTION
                        AudioSectionView(
                            title: "Output",
                            systemIcon: "speaker.wave.3.fill",
                            iconColor: .blue,
                            devices: audio.outputDevices,
                            selectedDevice: audio.selectedOutputDevice,
                            volume: $audio.outputVolume,
                            muted: audio.outputMuted,
                            showLevel: false,
                            inputLevel: .constant(0),
                            onSelectDevice: { audio.setDefaultDevice($0, isInput: false) },
                            onVolumeChange: { audio.setVolume($0, isInput: false) },
                            onMuteToggle: { audio.toggleMute(isInput: false) }
                        )

                        Divider().padding(.horizontal, 12)

                        // INPUT SECTION
                        AudioSectionView(
                            title: "Input",
                            systemIcon: "mic.fill",
                            iconColor: .green,
                            devices: audio.inputDevices,
                            selectedDevice: audio.selectedInputDevice,
                            volume: $audio.inputVolume,
                            muted: audio.inputMuted,
                            showLevel: true,
                            inputLevel: $audio.inputLevel,
                            onSelectDevice: { audio.setDefaultDevice($0, isInput: true) },
                            onVolumeChange: { audio.setVolume($0, isInput: true) },
                            onMuteToggle: { audio.toggleMute(isInput: true) }
                        )
                    }
                    .padding(12)
                }
            }

            Divider()

            // Footer
            HStack {
                Button(action: { audio.refresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button("Open Sound Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    Label("Quit", systemImage: "power")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }
}

// MARK: - Audio Section
struct AudioSectionView: View {
    let title: String
    let systemIcon: String
    let iconColor: Color
    let devices: [AudioDevice]
    let selectedDevice: AudioDevice?
    @Binding var volume: Float
    let muted: Bool
    let showLevel: Bool
    @Binding var inputLevel: Float
    let onSelectDevice: (AudioDevice) -> Void
    let onVolumeChange: (Float) -> Void
    let onMuteToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Image(systemName: systemIcon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            // Device picker
            if !devices.isEmpty {
                VStack(spacing: 4) {
                    ForEach(devices) { device in
                        DeviceRowView(
                            device: device,
                            isSelected: selectedDevice?.id == device.id,
                            onTap: { onSelectDevice(device) }
                        )
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            } else {
                Text("No \(title.lowercased()) devices found")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(8)
            }

            // Volume slider
            HStack(spacing: 8) {
                Button(action: onMuteToggle) {
                    Image(systemName: muteIcon)
                        .foregroundColor(muted ? .red : .primary)
                        .font(.system(size: 14))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { Double(volume) },
                        set: { onVolumeChange(Float($0)) }
                    ),
                    in: 0...1
                )
                .accentColor(muted ? .red : iconColor)
                .disabled(muted)

                Text("\(Int(volume * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    private var muteIcon: String {
        if title == "Output" {
            return muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        } else {
            return muted ? "mic.slash.fill" : "mic.fill"
        }
    }
}

// MARK: - Device Row
struct DeviceRowView: View {
    let device: AudioDevice
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: transportIcon(device.transportType))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .font(.system(size: 12))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    Text(device.transportType)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    func transportIcon(_ type: String) -> String {
        switch type {
        case "Bluetooth": return "wave.3.right"
        case "USB": return "cable.connector"
        case "HDMI": return "display"
        case "Built-in": return "macbook"
        case "Virtual": return "cpu"
        default: return "headphones"
        }
    }
}

// MARK: - Level Meter
struct LevelMeterView: View {
    let level: Float
    private let segments = 20

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<segments, id: \.self) { i in
                    let threshold = Float(i) / Float(segments)
                    let active = level > threshold
                    RoundedRectangle(cornerRadius: 2)
                        .fill(active ? segmentColor(i) : Color.secondary.opacity(0.2))
                        .animation(.linear(duration: 0.05), value: active)
                }
            }
        }
    }

    func segmentColor(_ index: Int) -> Color {
        if index < 14 { return .green }
        if index < 17 { return .yellow }
        return .red
    }
}
