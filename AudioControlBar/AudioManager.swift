import Foundation
import CoreAudio
import AVFoundation
import Combine
import SwiftUI

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let isInput: Bool
    let isOutput: Bool
    let transportType: String
    
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id
    }
}

class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var inputDevices: [AudioDevice] = []
    @Published var outputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var selectedOutputDevice: AudioDevice?
    @Published var inputVolume: Float = 0.5
    @Published var outputVolume: Float = 0.5
    @Published var inputMuted: Bool = false
    @Published var outputMuted: Bool = false
    @Published var inputLevel: Float = 0.0  // real-time VU meter

    private var levelTimer: Timer?
    private var listenerAdded = false
    private var prevOutputVolumeBeforeMute: Float = 0.5
    private var prevInputVolumeBeforeMute: Float = 0.5

    private init() {
        refresh()
        startLevelMonitor()
        addSystemListener()
    }

    deinit {
        levelTimer?.invalidate()
    }

    // MARK: - Refresh
    func refresh() {
        let devices = allAudioDevices()
        DispatchQueue.main.async {
            self.inputDevices = devices.filter { $0.isInput }
            self.outputDevices = devices.filter { $0.isOutput }

            let defaultInput = self.getDefaultDevice(isInput: true)
            let defaultOutput = self.getDefaultDevice(isInput: false)

            if defaultInput != 0, let dev = self.inputDevices.first(where: { $0.id == defaultInput }) {
                self.selectedInputDevice = dev
            } else {
                self.selectedInputDevice = self.inputDevices.first
            }

            if defaultOutput != 0, let dev = self.outputDevices.first(where: { $0.id == defaultOutput }) {
                self.selectedOutputDevice = dev
            } else {
                self.selectedOutputDevice = self.outputDevices.first
            }

            if let inp = self.selectedInputDevice {
                self.inputVolume = self.getVolume(deviceID: inp.id, isInput: true)
            }
            if let out = self.selectedOutputDevice {
                self.outputVolume = self.getVolume(deviceID: out.id, isInput: false)
            }
        }
    }

    // MARK: - Device List
    private func allAudioDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else { return [] }

        return deviceIDs.compactMap { makeDevice(id: $0) }
    }

    private func makeDevice(id: AudioDeviceID) -> AudioDevice? {
        let name = getStringProperty(id: id, selector: kAudioDevicePropertyDeviceNameCFString) ?? "Unknown"
        let uid = getStringProperty(id: id, selector: kAudioDevicePropertyDeviceUID) ?? UUID().uuidString
        let transport = getTransportType(id: id)
        let hasInput = channelCount(id: id, isInput: true) > 0
        let hasOutput = channelCount(id: id, isInput: false) > 0

        guard hasInput || hasOutput else { return nil }

        return AudioDevice(id: id, name: name, uid: uid, isInput: hasInput, isOutput: hasOutput, transportType: transport)
    }

    private func getStringProperty(id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // First query the size of the property data
        var dataSize: UInt32 = 0
        let hasSize = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr
        guard hasSize, dataSize == UInt32(MemoryLayout<CFString?>.size) || dataSize == UInt32(MemoryLayout<CFString>.size) else {
            return nil
        }

        var cfValue: CFString? = nil
        let status = withUnsafeMutablePointer(to: &cfValue) { ptr -> OSStatus in
            return AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, ptr)
        }
        guard status == noErr, let cfString = cfValue else { return nil }
        return cfString as String
    }

    private func channelCount(id: AudioDeviceID, isInput: Bool) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr else { return 0 }
        guard dataSize > 0 else { return 0 }

        let bufferListPtr = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPtr.deallocate() }

        guard AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, bufferListPtr) == noErr else { return 0 }

        let abl = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        var channels = 0
        for buffer in abl {
            channels += Int(buffer.mNumberChannels)
        }
        return channels
    }

    private func getTransportType(id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &value) == noErr else { return "Built-in" }
        switch value {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        case kAudioDeviceTransportTypeVirtual: return "Virtual"
        default: return "Other"
        }
    }

    // MARK: - Default Device
    private func getDefaultDevice(isInput: Bool) -> AudioDeviceID {
        let selector = isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID)
        return status == noErr ? deviceID : 0
    }

    func setDefaultDevice(_ device: AudioDevice, isInput: Bool) {
        let selector = isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var deviceID = device.id
        guard deviceID != 0 else { return }
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, dataSize, &deviceID)
        guard status == noErr else {
            print("Failed to set default device (status: \(status))")
            return
        }

        DispatchQueue.main.async {
            if isInput {
                self.selectedInputDevice = device
                self.inputVolume = self.getVolume(deviceID: device.id, isInput: true)
            } else {
                self.selectedOutputDevice = device
                self.outputVolume = self.getVolume(deviceID: device.id, isInput: false)
            }
        }
    }

    // MARK: - Volume
    func getVolume(deviceID: AudioDeviceID, isInput: Bool) -> Float {
        guard deviceID != 0 else { return 0.0 }
        let scope: AudioObjectPropertyScope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, mScope: scope, mElement: kAudioObjectPropertyElementMain)

        if !AudioObjectHasProperty(deviceID, &address) {
            address.mSelector = kAudioDevicePropertyVolumeScalar
        }

        var volume: Float32 = 0.0
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &volume)
        if status != noErr {
            // If we can't read volume, return 0 rather than propagating an error
            return 0.0
        }
        return volume
    }

    func setVolume(_ volume: Float, isInput: Bool) {
        let deviceID = isInput ? selectedInputDevice?.id : selectedOutputDevice?.id
        guard let id = deviceID, id != 0 else { return }

        let scope: AudioObjectPropertyScope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, mScope: scope, mElement: kAudioObjectPropertyElementMain)

        if !AudioObjectHasProperty(id, &address) {
            address.mSelector = kAudioDevicePropertyVolumeScalar
        }

        var vol = volume
        let dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(id, &address, 0, nil, dataSize, &vol)
        if status != noErr {
            print("Failed to set volume (status: \(status))")
            return
        }

        DispatchQueue.main.async {
            if isInput { self.inputVolume = volume } else { self.outputVolume = volume }
        }
    }

    // MARK: - Mute
    func toggleMute(isInput: Bool) {
        if isInput {
            if inputMuted {
                setVolume(prevInputVolumeBeforeMute, isInput: true)
                DispatchQueue.main.async { self.inputMuted = false }
            } else {
                prevInputVolumeBeforeMute = inputVolume
                setVolume(0.0, isInput: true)
                DispatchQueue.main.async { self.inputMuted = true }
            }
        } else {
            if outputMuted {
                setVolume(prevOutputVolumeBeforeMute, isInput: false)
                DispatchQueue.main.async { self.outputMuted = false }
            } else {
                prevOutputVolumeBeforeMute = outputVolume
                setVolume(0.0, isInput: false)
                DispatchQueue.main.async { self.outputMuted = true }
            }
        }
    }

    // MARK: - Input Level Meter
    private func startLevelMonitor() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateInputLevel()
        }
    }

    private func updateInputLevel() {
        let level = getAudioInputLevel()
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.05)) {
                self.inputLevel = level
            }
        }
    }

    private var audioEngine: AVAudioEngine?
    private var engineStarted = false

    func startInputMeter() {
        guard !engineStarted else { return }

        // On macOS, AVAudioSession is unavailable. Use AVCaptureDevice to request microphone access.
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    print("Microphone permission not granted")
                    return
                }
                let engine = AVAudioEngine()
                let inputNode = engine.inputNode
                let format = inputNode.inputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                    let level = self?.calculateLevel(buffer: buffer) ?? 0.0
                    DispatchQueue.main.async {
                        self?.inputLevel = min(1.0, level * 3)
                    }
                }
                do {
                    try engine.start()
                    self.audioEngine = engine
                    self.engineStarted = true
                } catch {
                    print("Audio engine error: \(error)")
                }
            }
        }
    }

    func stopInputMeter() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        engineStarted = false
        inputLevel = 0.0
    }

    private func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var rms: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[0][i]
            rms += sample * sample
        }
        rms = sqrt(rms / Float(frameLength))
        return rms
    }

    private func getAudioInputLevel() -> Float {
        // Fallback if engine not started
        return 0.0
    }

    // MARK: - System listener
    private func addSystemListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main) { [weak self] _, _ in
            self?.refresh()
        }
    }
}
