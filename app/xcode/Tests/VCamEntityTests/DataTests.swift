//
//  DataTests.swift
//
//
//  Created by Tatsuya Tanaka on 2025/11/15.
//

import Testing
import Foundation
@testable import VCamEntity

@Suite
struct DataBase64URLTests {
    // MARK: - Roundtrip Tests (Encoding + Decoding)

    @Test("Hello World roundtrip")
    func helloWorld() throws {
        let text = "Hello World"
        let data = Data(text.utf8)

        // Encoding
        let encoded = data.base64URLEncodedString()
        #expect(encoded == "SGVsbG8gV29ybGQ") // No padding
        #expect(!encoded.contains("="))

        // Decoding
        let decoded = try #require(Data(base64URLEncoded: encoded))
        let decodedString = try #require(String(data: decoded, encoding: .utf8))
        #expect(decodedString == text)
    }

    @Test("Roundtrip with various strings")
    func roundtrip() throws {
        let testCases = [
            "a",
            "ab",
            "abc",
            "abcd",
            "abcde",
            "Hello World",
            "The quick brown fox jumps over the lazy dog. This is a test of base64url encoding and decoding.",
            "こんにちは世界 🌍",
            "🎉🎊🎈",
        ]

        for testCase in testCases {
            let data = Data(testCase.utf8)
            let encoded = data.base64URLEncodedString()

            // Verify no URL-unsafe characters
            #expect(!encoded.contains("+"))
            #expect(!encoded.contains("/"))
            #expect(!encoded.contains("="))

            // Verify roundtrip
            let decoded = try #require(Data(base64URLEncoded: encoded))
            let decodedString = try #require(String(data: decoded, encoding: .utf8))
            #expect(decodedString == testCase)
        }
    }

    @Test("Binary data roundtrip")
    func binaryData() throws {
        let binaryData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0xFF, 0xFE, 0xFD])

        // Encoding
        let encoded = binaryData.base64URLEncodedString()
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))

        // Decoding
        let decoded = try #require(Data(base64URLEncoded: encoded))
        #expect(decoded == binaryData)
    }

    @Test("Padding scenarios roundtrip")
    func paddingScenarios() throws {
        let testCases = [
            ("a", 2),     // Base64: "YQ==" -> Base64URL: "YQ" (2 padding removed)
            ("ab", 1),    // Base64: "YWI=" -> Base64URL: "YWI" (1 padding removed)
            ("abc", 0),   // Base64: "YWJj" -> Base64URL: "YWJj" (no padding)
            ("abcd", 0),  // Base64: "YWJjZA==" -> Base64URL: "YWJjZA" (2 padding removed)
        ]

        for (text, _) in testCases {
            let data = Data(text.utf8)
            let encoded = data.base64URLEncodedString()

            // Verify no padding
            #expect(!encoded.contains("="))

            // Verify roundtrip
            let decoded = try #require(Data(base64URLEncoded: encoded))
            let decodedString = try #require(String(data: decoded, encoding: .utf8))
            #expect(decodedString == text)
        }
    }

    // MARK: - Encoding-Specific Tests

    @Test("URL-unsafe characters are replaced")
    func urlUnsafeCharacters() throws {
        // Test data that produces + and / in standard base64
        let testData = Data([0x6b, 0xf8, 0x1f, 0x71]) // Creates base64: "a/gfcQ=="
        let base64URL = testData.base64URLEncodedString()

        // Should not contain +, /, or =
        #expect(!base64URL.contains("+"))
        #expect(!base64URL.contains("/"))
        #expect(!base64URL.contains("="))

        // Should be: "a_gfcQ"
        #expect(base64URL == "a_gfcQ")
    }

    @Test("Empty data encoding")
    func emptyDataEncoding() throws {
        let data = Data()
        let base64URL = data.base64URLEncodedString()
        #expect(base64URL == "")
    }

    @Test("JWT header encoding")
    func jwtHeaderEncoding() throws {
        let jwtHeader = #"{"alg":"EdDSA","typ":"JWT"}"#
        let data = Data(jwtHeader.utf8)
        let base64URL = data.base64URLEncodedString()

        #expect(base64URL == "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9")
    }

    @Test("PKCE code_verifier encoding")
    func pkceCodeVerifier() throws {
        // Simulate PKCE code_verifier generation (32 bytes -> 43 characters)
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        let data = Data(bytes)
        let codeVerifier = data.base64URLEncodedString()

        // Verify length (should be 43 characters for 32 bytes)
        #expect(codeVerifier.count == 43)

        // Verify no URL-unsafe characters
        #expect(!codeVerifier.contains("+"))
        #expect(!codeVerifier.contains("/"))
        #expect(!codeVerifier.contains("="))

        // Verify roundtrip
        let decoded = try #require(Data(base64URLEncoded: codeVerifier))
        #expect(decoded == data)
    }

    // MARK: - Decoding-Specific Tests

    @Test("Decoding without padding")
    func decodingWithoutPadding() throws {
        // Base64URL without padding
        let base64URL = "SGVsbG8gV29ybGQ"
        let data = try #require(Data(base64URLEncoded: base64URL))
        let string = try #require(String(data: data, encoding: .utf8))
        #expect(string == "Hello World")
    }

    @Test("Decoding with existing padding")
    func decodingWithPadding() throws {
        // Test that it works even if padding is already present
        let withPadding = "SGVsbG8gV29ybGQ="
        let data = try #require(Data(base64URLEncoded: withPadding))
        let string = try #require(String(data: data, encoding: .utf8))
        #expect(string == "Hello World")
    }

    @Test("Decoding with URL-safe characters")
    func decodingUrlSafeCharacters() throws {
        // Base64URL: "a_gfcQ" (contains _ which is URL-safe)
        let base64URL = "a_gfcQ"
        let data = try #require(Data(base64URLEncoded: base64URL))
        #expect(data == Data([0x6b, 0xf8, 0x1f, 0x71]))
    }

    @Test("JWT header decoding")
    func jwtHeaderDecoding() throws {
        let jwtHeader = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9"
        let data = try #require(Data(base64URLEncoded: jwtHeader))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json == #"{"alg":"EdDSA","typ":"JWT"}"#)
    }

    @Test("JWT payload decoding")
    func jwtPayloadDecoding() throws {
        let jwtPayload = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
        let data = try #require(Data(base64URLEncoded: jwtPayload))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json == #"{"sub":"1234567890","name":"John Doe","iat":1516239022}"#)
    }

    @Test("Empty string decoding")
    func emptyStringDecoding() throws {
        let data = try #require(Data(base64URLEncoded: ""))
        #expect(data.count == 0)
    }

    // MARK: - Edge Cases

    @Test("Invalid string returns nil")
    func invalidString() throws {
        let invalidBase64URL = "!!!invalid!!!"
        let data = Data(base64URLEncoded: invalidBase64URL)
        #expect(data == nil)
    }

    @Test("Whitespace handling")
    func whitespace() throws {
        // Base64 decoding typically doesn't handle whitespace well
        let withWhitespace = "SGVs bG8g V29y bGQ"
        let data = Data(base64URLEncoded: withWhitespace)
        #expect(data == nil)
    }
}
