import Testing
import CoreGraphics
import VCamBridge
import struct SwiftUI.Binding
import struct SwiftUI.Color

@MainActor
@Suite
struct ValueBindingTests {
    private enum TestType: Int32, Sendable {
        case value
    }

    @MainActor
    private class ValueStore<T: ValueBindingDefaultValue & Sendable> {
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

    @Test
    func int32() throws {
        let store = ValueStore(123 as Int32)
        #expect(store.value == 123)

        store.value = 321
        #expect(store.value == 321)
        #expect(store.value == store.store)
    }

    @Test
    func cgFloat() throws {
        let store = ValueStore(123 as CGFloat)
        #expect(store.value == 123)

        store.value = 321
        #expect(store.value == 321)
        #expect(store.value == store.store)
    }

    @Test
    func bool() throws {
        let store = ValueStore(false)
        #expect(store.value == false)

        store.value = true
        #expect(store.value == true)
        #expect(store.value == store.store)
    }

    @Test
    func string() throws {
        let store = ValueStore("hello")
        #expect(store.value == "hello")

        store.value = "world"
        #expect(store.value == "world")
        #expect(store.value == store.store)
    }

    @Test
    func void() throws {
        let binding = ValueBinding<Void, TestType>()
        let trigger = binding.trigger(.value)

        var getCalled = false
        var setCalled = false

        binding.getValue = { _ in getCalled = true }
        binding.setValue = { _, _ in setCalled = true }

        trigger()
        #expect(getCalled == true)
        #expect(setCalled == false)
    }

    @Test
    func color2() throws {
        let store = ValueStore(Color.purple)
        #expect(store.value == .purple)

        store.value = .yellow
        #expect(store.value == .yellow)
        #expect(store.value == store.store)
    }

    @Test
    func color() throws {
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

        #expect(value.wrappedValue == initialColor)

        value.wrappedValue = updatedColor
        #expect(value.wrappedValue == updatedColor)
        #expect(value.wrappedValue == store)
    }

    @Test
    func array() throws {
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

        #expect(value.wrappedValue == [1, 2, 3])

        value.wrappedValue = [2, 1, 0]
        #expect(value.wrappedValue == [2, 1, 0])
        #expect(value.wrappedValue == store)
    }
}
