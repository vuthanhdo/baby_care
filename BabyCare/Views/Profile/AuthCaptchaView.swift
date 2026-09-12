import SwiftUI
import WebKit

nonisolated enum AuthValidation {
    static func emailError(_ raw: String) -> String? {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return L10n.text("Vui lòng nhập email.") }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard email.utf8.count <= 254, parts.count == 2 else { return L10n.text("Email không hợp lệ. Ví dụ: bome@gmail.com.") }
        let local = String(parts[0]), domain = String(parts[1])
        let localAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!#$%&'*+-/=?^_`{|}~")
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        let valid = !local.isEmpty && local.utf8.count <= 64 && !local.hasPrefix(".") && !local.hasSuffix(".") && !local.contains("..")
            && local.unicodeScalars.allSatisfy { localAllowed.contains($0) }
            && labels.count >= 2 && labels.allSatisfy { label in
                !label.isEmpty && label.count <= 63 && !label.hasPrefix("-") && !label.hasSuffix("-")
                    && label.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-").contains($0) }
            } && (labels.last?.count ?? 0) >= 2
        return valid ? nil : L10n.text("Email không hợp lệ. Ví dụ: bome@gmail.com.")
    }
    static func passwordError(_ password: String) -> String? {
        if password.isEmpty { return L10n.text("Vui lòng nhập mật khẩu.") }
        var missing: [String] = []
        if password.count < 8 { missing.append(L10n.text("ít nhất 8 ký tự")) }
        if !password.unicodeScalars.contains(where: CharacterSet.uppercaseLetters.contains) { missing.append(L10n.text("1 chữ hoa")) }
        if !password.unicodeScalars.contains(where: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{};':\"\\|,.<>/?`~").contains) { missing.append(L10n.text("1 ký tự đặc biệt (ví dụ !, @, #)")) }
        return missing.isEmpty ? nil : L10n.text("Mật khẩu cần ") + missing.joined(separator: ", ") + "."
    }
    static func confirmationError(password: String, confirmation: String) -> String? {
        if confirmation.isEmpty { return L10n.text("Vui lòng nhập lại mật khẩu.") }
        return password == confirmation ? nil : L10n.text("Mật khẩu nhập lại không khớp.")
    }
    static func signupError(password: String, confirmation: String) -> String? {
        passwordError(password) ?? confirmationError(password: password, confirmation: confirmation)
    }
}

enum AuthCaptchaConfiguration {
    /// Enable together with Supabase bot protection after configuring the hosted widget.
    static var isEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "AuthCaptchaEnabled") as? Bool ?? false
    }

    static var pageURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "AuthCaptchaPageURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

/// Only the configured HTTPS page can deliver a token; Supabase verifies it server-side.
struct AuthCaptchaView: UIViewRepresentable {
    let url: URL
    @Binding var token: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "captcha")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.parent = self }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "captcha")
    }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: AuthCaptchaView
        init(_ parent: AuthCaptchaView) { self.parent = parent }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  message.frameInfo.request.url?.host == parent.url.host,
                  message.frameInfo.request.url?.scheme == "https",
                  let value = message.body as? String else { return }
            parent.token = value.isEmpty ? nil : value
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.token = nil }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.token = nil }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.targetFrame?.isMainFrame == true {
                let target = navigationAction.request.url
                decisionHandler(target?.scheme == "https" && target?.host == parent.url.host ? .allow : .cancel)
            } else { decisionHandler(.allow) }
        }
    }
}
