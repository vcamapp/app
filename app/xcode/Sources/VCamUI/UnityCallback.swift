//
//  UnityCallback.swift
//
//
//  Created by Tatsuya Tanaka on 2023/01/21.
//

import Foundation
import VCamData
import VCamBridge
import VCamCamera
import VCamTracking
import VCamLogger
import VCamEntity

@_cdecl("uniOnVCamSystemStart")
public func uniOnVCamSystemStart() {
    Logger.log("uniOnVCamSystemStart")
    VCamSystem.shared.isUniVCamSystemEnabled = true
    VCamSystem.shared.startSystem()
    Tracking.shared.configure()
    VCamUIState.shared.interactable = true
    UniReload.Reloader.shared.reload()
}

@_cdecl("uniOnVCamSystemDestroy")
public func uniOnVCamSystemDestroy() {
    Logger.log("uniOnVCamSystemDestroy")
    VCamSystem.shared.isUniVCamSystemEnabled = false
    VCamUIState.shared.interactable = false
    Tracking.shared.stop()
    UniReload.Reloader.shared.reload()
}

@_cdecl("uniOnApplyCaptureSystem")
public func uniOnApplyCaptureSystem() {
    UniBridge.shared.useFullTracking(UserDefaults.standard.value(for: .integrationMocopi))
    Tracking.shared.updateLipSyncIfNeeded()

    UniBridge.cachedBlendShapes = UniBridge.shared.blendShapes.components(separatedBy: ",")
        .map { VCamEntity.BlendShape(name: $0) }
}

@_cdecl("uniUseAutoConvertVRM1")
public func uniUseAutoConvertVRM1() -> Bool {
    UserDefaults.standard.value(for: .useAutoConvertVRM1)
}

@_cdecl("uniDisposeWindow")
public func uniDisposeWindow() {
    Logger.log("")
    VCamSystem.shared.windowManager.dispose()
}

@_cdecl("uniHideWindow")
public func uniHideWindow() {
    Logger.log("")
    VCamSystem.shared.windowManager.hide()
}

@_cdecl("uniReloadUI")
public func uniReloadUI() {
    guard VCamSystem.shared.windowManager.isConfigured,
          VCamSystem.shared.isUniVCamSystemEnabled else { return }
    UniReload.Reloader.shared.reload()
}

@_cdecl("uniUpdateRenderFrame")
public func uniUpdateRenderFrame() {
    guard VCamSystem.shared.windowManager.isConfigured else { return }
    VirtualCameraManager.shared.sendImageToVirtualCamera(
        with: MainTexture.shared.texture
    )

    VideoRecorder.shared.renderFrame(MainTexture.shared.texture)
}

@_cdecl("uniRegisterString")
public func uniRegisterString(_ get: @escaping @convention(c) (Int32) -> UnsafePointer<CChar>, _ set: @escaping @convention(c) (Int32, UnsafePointer<CChar>) -> Void) {
    UniBridge.shared.stringMapper.getValue = { String(cString: get($0.rawValue)) }
    UniBridge.shared.stringMapper.setValue = { set($0.rawValue, strdup($1)) }
}

@_cdecl("uniRegisterInt")
public func uniRegisterInt(_ get: @escaping @convention(c) (Int32) -> Int32, _ set: @escaping @convention(c) (Int32, Int32) -> Void) {
    UniBridge.shared.intMapper.getValue = { get($0.rawValue) }
    UniBridge.shared.intMapper.setValue = { set($0.rawValue, $1) }
}

@_cdecl("uniRegisterFloat")
public func uniRegisterFloat(_ get: @escaping @convention(c) (Int32) -> Float, _ set: @escaping @convention(c) (Int32, Float) -> Void) {
    UniBridge.shared.floatMapper.getValue = { CGFloat(get($0.rawValue)) }
    UniBridge.shared.floatMapper.setValue = { set($0.rawValue, Float($1)) }
}

@_cdecl("uniRegisterBool")
public func uniRegisterBool(_ get: @escaping @convention(c) (Int32) -> Bool, _ set: @escaping @convention(c) (Int32, Bool) -> Void) {
    UniBridge.shared.boolMapper.getValue = { get($0.rawValue) }
    UniBridge.shared.boolMapper.setValue = { set($0.rawValue, $1) }
}

@_cdecl("uniRegisterTrigger")
public func uniRegisterTrigger(_ trigger: @escaping @convention(c) (Int32) -> Void) {
    UniBridge.shared.triggerMapper.getValue = { trigger($0.rawValue) }
}

@_cdecl("uniRegisterStruct")
public func uniRegisterStruct(_ get: @escaping @convention(c) (Int32) -> UnsafeMutableRawPointer, _ set: @escaping @convention(c) (Int32, UnsafeMutableRawPointer) -> Void) {
    UniBridge.shared.structMapper.getValue = { get($0.rawValue) }
    UniBridge.shared.structMapper.setValue = { set($0.rawValue, $1) }
}

@_cdecl("uniRegisterArray")
public func uniRegisterArray(_ get: @escaping @convention(c) (Int32) -> UnsafeMutableRawPointer, _ set: @escaping @convention(c) (Int32, UnsafeMutableRawPointer) -> Void) {
    UniBridge.shared.arrayMapper.getValue = { get($0.rawValue) }
    UniBridge.shared.arrayMapper.setValue = { set($0.rawValue, $1) }
}
