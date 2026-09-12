import SwiftUI
import WebKit

enum AuthValidation {
    static func signupError(password: String, confirmation: String) -> String? {
        if password.count < 8 { return "Mật khẩu cần ít nhất 8 ký tự." }
        if password != confirmation { return "Mật khẩu nhập lại không khớp." }
        return nil
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
