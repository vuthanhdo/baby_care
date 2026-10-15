import Foundation
import Testing
@testable import BabyCare

struct AppleSignInTests {
    @Test func nonceIsRandomUrlSafeAndLongEnough() {
        let first = AppleSignInNonce.random(), second = AppleSignInNonce.random()
        #expect(first.count == 32 && second.count == 32 && first != second)
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        #expect(first.allSatisfy { allowed.contains($0) })
    }

    @Test func sha256MatchesKnownVector() {
        #expect(AppleSignInNonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(AppleSignInNonce.sha256("").count == 64)
    }
}
