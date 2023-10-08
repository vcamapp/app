//
//  ValueBindingTests.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/10/08.
//

import XCTest
import VCamBridge
import struct SwiftUI.Binding
import struct SwiftUI.Color

final class ValueBindingTests: XCTestCase {
    private enum TestType: Int32 {
        case value
    }

    private class ValueStore<T: ValueBindingDefaultValue> {
        var store: T
        let binding = ValueBinding<T, TestType>()

        @Binding var value: T

        init(_ store: T) {
            self.store = store
            _value = binding.binding(.value)
            binding.getValue = { _ in self.store }
            binding.setValue = { _, value in self.store = value }
        }
    }

    func testInt32() throws {
        let store = ValueStore(123 as Int32)
        XCTAssertEqual(store.value, 123)

        store.value = 321
        XCTAssertEqual(store.value, 321)
        XCTAssertEqual(store.value, store.store)
    }

    func testCGFloat() throws {
        let store = ValueStore(123 as CGFloat)
        XCTAssertEqual(store.value, 123)

        store.value = 321
        XCTAssertEqual(store.value, 321)
        XCTAssertEqual(store.value, store.store)
    }

    func testBool() throws {
        let store = ValueStore(false)
        XCTAssertEqual(store.value, false)

        store.value = true
        XCTAssertEqual(store.value, true)
        XCTAssertEqual(store.value, store.store)
    }

    func testString() throws {
        let store = ValueStore("hello")
        XCTAssertEqual(store.value, "hello")

        store.value = "world"
        XCTAssertEqual(store.value, "world")
        XCTAssertEqual(store.value, store.store)
    }

    func testVoid() throws {
        let binding = ValueBinding<Void, TestType>()
        let trigger = binding.trigger(.value)

        var getCalled = false
        var setCalled = false

        binding.getValue = { _ in getCalled = true }
        binding.setValue = { _, _ in setCalled = true }

        trigger()
        XCTAssertEqual(getCalled, true)
        XCTAssertEqual(setCalled, false)
    }

    func testColor2() throws {
        let store = ValueStore(Color.purple)
        XCTAssertEqual(store.value, .purple)

        store.value = .yellow
        XCTAssertEqual(store.value, .yellow)
        XCTAssertEqual(store.value, store.store)
    }

    func testColor() throws {
        let binding = ValueBinding<UnsafeMutableRawPointer, TestType>()

        let value = binding.binding(.value, type: Color.self)

        let initialColor = Color(.sRGB, red: 0, green: 1, blue: 0, opacity: 1)
        let updatedColor = Color(.sRGB, red: 1, green: 0, blue: 1, opacity: 0)
        var store = initialColor
        var pointerOwner = store.set()
        var pointer: UnsafeMutableRawPointer { pointerOwner.pointer }

        binding.getValue = { _ in pointer }
        binding.setValue = { _, newValue in
            store = Color.get(newValue)
            pointerOwner = store.set()
        }

        XCTAssertEqual(value.wrappedValue, initialColor)

        value.wrappedValue = updatedColor
        XCTAssertEqual(value.wrappedValue, updatedColor)
        XCTAssertEqual(value.wrappedValue, store)
    }

    func testArray() throws {
        let binding = ValueBinding<UnsafeMutableRawPointer, TestType>()

        let value = binding.binding(.value, size: 3, type: [Int32].self)

        var store: [Int32] = [1, 2, 3]

        binding.getValue = { _ in
            store.withContiguousStorageIfAvailable { buffer in
                UnsafeMutableRawPointer(mutating: buffer.baseAddress!)
            }!
        }
        binding.setValue = { _, newValue in
            store = [Int32].get(newValue, size: store.count)
            
        }

        XCTAssertEqual(value.wrappedValue, [1, 2, 3])

        value.wrappedValue = [2, 1, 0]
        XCTAssertEqual(value.wrappedValue, [2, 1, 0])
        XCTAssertEqual(value.wrappedValue, store)
    }
}
