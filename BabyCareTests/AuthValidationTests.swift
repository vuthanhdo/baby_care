import Testing
@testable import BabyCare

struct AuthValidationTests {
    @Test func emailFormats() {
        for value in ["parent@gmail.com", " me+test@example.co.uk "] { #expect(AuthValidation.emailError(value) == nil) }
        for value in ["", "a@", "a@@b.com", ".a@b.com", "a..b@c.com", "a b@c.com", "a@-b.com", "a@b..com", "a@localhost"] { #expect(AuthValidation.emailError(value) != nil) }
    }
    @Test func passwordRequirements() {
        #expect(AuthValidation.passwordError("Abcdefg!") == nil)
        for value in ["Abcde!", "abcdefgh!", "Abcdefgh", "Abcdefg ", ""] { #expect(AuthValidation.passwordError(value) != nil) }
    }

    @MainActor @Test func confirmationMustMatchExactly() {
        #expect(AuthValidation.signupError(password: "Password!23", confirmation: "Password!23") == nil)
        #expect(AuthValidation.signupError(password: "Password!23", confirmation: "password!23") != nil)
        #expect(AuthValidation.signupError(password: "Password!23", confirmation: "Password!23 ") != nil)
        #expect(AuthValidation.signupError(password: "Password!23", confirmation: "") != nil)
        #expect(AuthValidation.signupError(password: "short", confirmation: "short") != nil)
    }
}
