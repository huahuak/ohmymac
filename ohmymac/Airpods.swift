//
//  Airpods.swift
//  ohmymac
//
//  Created by Hua on 2025/1/8.
//

import Foundation
import CoreAudio
import AudioToolbox

func startAirpodsService() {
    registerDefaultAudioDeviceChangeListener()
}

func audioDeviceChanged(
    numberOfAddresses: UInt32,
    addresses: UnsafePointer<AudioObjectPropertyAddress>
) {
    print("Audio device changed")
    guard let airpods = getAirPodsDeviceID() else { return }
    do {
        let volume: Float = 0.1875
        if try readVolume(deviceID: airpods) <= volume { return }
        try setVolume(deviceID: airpods, volume)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            setVolume(to: volume)
        }
        notify(msg: "Reset Headphone Volume.")
    } catch {
        print("AirPods Sound Service Error! \(error)")
        debugNotify(msg: "AirPods Sound Service Error! \(error)")
    }
    return
}

private func registerDefaultAudioDeviceChangeListener() {
    var defaultDevicePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    let status = AudioObjectAddPropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &defaultDevicePropertyAddress,
        DispatchQueue.main,
        audioDeviceChanged
    )
   
    if status == noErr {
        print("Listener registered successfully")
    } else {
        print("Failed to register listener: \(status)")
    }
}

private func removeDefaultAudioDeviceChangeListener() {
    var defaultDevicePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    let audioObjectID = AudioObjectID(kAudioObjectSystemObject)
    
    let status = AudioObjectRemovePropertyListenerBlock(
        audioObjectID,
        &defaultDevicePropertyAddress,
        DispatchQueue.main,
        audioDeviceChanged
    )
    
    if status == noErr {
        print("Listener removed successfully")
    } else {
        print("Failed to remove listener: \(status)")
    }
}

enum Errors: Error {
    /// The system couldn't complete the requested operation and
    /// returned the given status.
    case  operationFailed(OSStatus)
    /// The current default output device doesn't support the requested property.
    case  unsupportedProperty
    /// The current default output device doesn't allow changing the requested property.
    case  immutableProperty
    /// There is no default output device.
    case  noDevice
}

public func readVolume(deviceID: AudioDeviceID) throws -> Float {
    var size = UInt32(MemoryLayout<Float32>.size)
    var volume: Float = 0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    // Ensure the device has a volume property.
    guard AudioObjectHasProperty(deviceID, &address) else {
        throw Errors.unsupportedProperty
    }
    
    let error = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
    guard error == noErr else {
        throw Errors.operationFailed(error)
    }
    
    return min(max(0, volume), 1)
}

public func setVolume(deviceID: AudioDeviceID, _ newValue: Float) throws {
    var normalizedValue = min(max(0, newValue), 1)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    // Ensure the device has a volume property.
    guard AudioObjectHasProperty(deviceID, &address) else {
        throw Errors.unsupportedProperty
    }
    
    var canChangeVolume = DarwinBoolean(true)
    let size = UInt32(MemoryLayout<Float>.size(ofValue: normalizedValue))
    let isSettableError = AudioObjectIsPropertySettable(deviceID, &address, &canChangeVolume)
    
    // Ensure the volume property is editable.
    guard isSettableError == noErr else {
        throw Errors.operationFailed(isSettableError)
    }
    guard canChangeVolume.boolValue else {
        throw Errors.immutableProperty
    }
    
    let error = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &normalizedValue)
    
    if error != noErr {
        throw Errors.operationFailed(error)
    }
}

func getAllOutputDeviceIDs() -> [AudioDeviceID] {
    var deviceIDs: [AudioDeviceID] = []
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
    )
    
    var deviceCount: UInt32 = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    
    let status = AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &size
    )
    
    guard status == noErr else {
        print("Error: Unable to get the size of the audio device list")
        return []
    }
    
    deviceCount = size / UInt32(MemoryLayout<AudioDeviceID>.size)
    
    var audioDevices = [AudioDeviceID](repeating: AudioObjectID(kAudioObjectUnknown), count: Int(deviceCount))
    
    let statusDevices = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &size,
        &audioDevices
    )
    
    guard statusDevices == noErr else {
        print("Error: Unable to get the list of audio devices")
        return []
    }
    
    func isOutputDevice(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        var streamCount: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &size
        )
        
        guard status == noErr else {
            return false
        }
        
        streamCount = size / UInt32(MemoryLayout<AudioStreamID>.size)
        return streamCount > 0
    }
    
    for deviceID in audioDevices {
        if isOutputDevice(deviceID: deviceID) {
            deviceIDs.append(deviceID)
        }
    }
    
    return deviceIDs
}


func getDeviceName(deviceID: AudioDeviceID) -> String? {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    var deviceName: CFString? = nil
    var size = UInt32(MemoryLayout<CFString?>.size)
    
    let status = AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &size,
        &deviceName
    )
    
    guard status == noErr, let cfDeviceName = deviceName else {
        print("Error: Unable to get device name")
        return nil
    }
    
    return cfDeviceName as String
}

func getAirPodsDeviceID() -> AudioDeviceID? {
    return getAllOutputDeviceIDs().first(where: { id in
        if let name = getDeviceName(deviceID: id),
           name.contains("AirPods") {
            return true
        }
        return false
    })
}

func getMacbookDeviceID() -> AudioDeviceID? {
    return getAllOutputDeviceIDs().first(where: { id in
        if let name = getDeviceName(deviceID: id),
           name.contains("Mac") {
            return true
        }
        return false
    })
}

func setVolume(to volume: Float) {
    let volume = volume * 100
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", "set volume output volume \(volume)"] // 设置参数

    do {
        try process.run()
        process.waitUntilExit()
        print("Volume set to \(volume)%")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}
