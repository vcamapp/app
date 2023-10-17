//
//  UniBridgeStub.swift
//
//
//  Created by Tatsuya Tanaka on 2023/10/18.
//

import Foundation
import VCamBridge

public final class UniBridgeStub {
    public static let shared = UniBridgeStub()

    private var boolTypes: [UniBridge.BoolType: Bool] = [.interactable: true, .hasPerfectSyncBlendShape: true, .useAddToMacOSMenuBar: true]
    private var intTypes: [UniBridge.IntType: Int32] = [:]
    private var floatTypes: [UniBridge.FloatType: CGFloat] = [:]
    private var stringTypes: [UniBridge.StringType: String] = [
        .allDisplayParameterPresets: "0@Test1,1@Test2",
        .blendShapes: "A,I,U,E,O,Angry,Fun,Joy,Sorrow,Surprised,AAAAAAAA,BBBBBBBB,CCCCCC,DDDDDD,EEEE,FFFFFFF,GGGGGGG",
    ]
    private lazy var arrayTypes: [UniBridge.ArrayType: UnsafeMutableRawPointer] = [
        .canvasSize: canvasSize.withUnsafeMutableBufferPointer { pointer in
            UnsafeMutableRawPointer(pointer.baseAddress!)
        }!,
        .screenResolution: screenResolution.withUnsafeMutableBufferPointer { pointer in
            UnsafeMutableRawPointer(pointer.baseAddress!)
        }!,
    ]

    private var emptyArray: [Float] = []
    private lazy var emptyArrayPointer = UnsafeMutableRawPointer(emptyArray.withUnsafeMutableBufferPointer { $0.baseAddress! })
    private var canvasSize: [Float] = [1920, 1080]
    private var screenResolution: [Int32] = [1920, 1080]

    public func stub(_ action: UniBridge) {
        action.stringMapper.getValue = { type in self.stringTypes[type] ?? "" }
        action.stringMapper.setValue = { type, value in self.stringTypes[type] = value }
        action.floatMapper.getValue = { type in self.floatTypes[type] ?? 0 }
        action.floatMapper.setValue = { type, value in self.floatTypes[type] = value }
        action.boolMapper.getValue = { type in self.boolTypes[type] ?? false }
        action.boolMapper.setValue = { type, value in self.boolTypes[type] = value }
        action.intMapper.getValue = { type in return self.intTypes[type] ?? 0 }
        action.intMapper.setValue = { type, value in self.intTypes[type] = value }
        action.arrayMapper.getValue = { type in return self.arrayTypes[type] ?? self.emptyArrayPointer }
        action.arrayMapper.setValue = { type, value in self.arrayTypes[type] = value }
    }
}
