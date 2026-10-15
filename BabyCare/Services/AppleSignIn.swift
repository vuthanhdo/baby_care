import CryptoKit
import Foundation

/// Nonce handling for Sign in with Apple: Apple receives the SHA-256 of a random nonce, Supabase the raw one
/// and checks it against the `nonce` claim of the identity token.
nonisolated enum AppleSignInNonce {
    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    static func random(length: Int = 32) -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
