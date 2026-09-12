import Testing
@testable import BabyCare

struct AuthValidationTests {
    @MainActor @Test func confirmationMustMatchExactly() {
        #expect(AuthValidation.signupError(password: "Password123", confirmation: "Password123") == nil)
        #expect(AuthValidation.signupError(password: "Password123", confirmation: "password123") != nil)
        #expect(AuthValidation.signupError(password: "Password123", confirmation: "Password123 ") != nil)
        #expect(AuthValidation.signupError(password: "Password123", confirmation: "") != nil)
        #expect(AuthValidation.signupError(password: "short", confirmation: "short") != nil)
    }
}
