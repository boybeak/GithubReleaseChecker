import Foundation
import SwiftUI
import AppKit
import SwiftUIWindow
import WebKit

public struct ReleaseInfo: Decodable {
    public let tagName: String
    public let name: String?
    public let log: String?
    public let htmlUrl: String // 下载链接地址

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case log = "body"
        case htmlUrl = "html_url"
    }
}

@available(macOS 11, *)
public class GithubReleaseChecker : @unchecked Sendable {
    public typealias CheckResultCallback = @Sendable (Result<(newVersion: ReleaseInfo?, hasUpdate: Bool), Error>) -> Void

    private let session: URLSession
    private let releaseVM = ReleaseVM()
    
    public var width: CGFloat = 360
    public var height: CGFloat = 480

    // 新增的版本比较器属性
    public var versionComparator: ((String, ReleaseInfo) -> Bool)?

    public init(session: URLSession = .shared) {
        self.session = session
        // 设置默认版本比较器
        self.versionComparator = { currentVersion, latestRelease in
            return self.compareVersions(currentVersion, latestRelease.tagName)
        }
    }

    public enum InputType {
        case url(URL)
        case userRepo(String)
        case gitUrl(URL)
    }

    public enum CheckerError: Error, Sendable {
        case invalidInput
        case networkError(Error)
        case invalidResponse
        case noReleases
        case cantGetCurrentVersion
    }

    public func checkUpdate(for input: InputType, showDefaultUI: Bool = false, onCheckResult: @escaping CheckResultCallback) {
        var progressIndicator: NSWindow? = nil
        if showDefaultUI {
            progressIndicator = showLoadingIndicator()
        }
        releaseVM.isLoading = true

        guard let currentVersion = getCurrentAppVersion() else {
            onCheckResult(.failure(CheckerError.cantGetCurrentVersion))
            DispatchQueue.main.async {
                progressIndicator?.close()
            }
            return
        }

        guard let apiURL = buildAPIURL(from: input) else {
            onCheckResult(.failure(CheckerError.invalidInput))
            DispatchQueue.main.async {
                progressIndicator?.close()
            }
            return
        }

        let task = session.dataTask(with: apiURL) { (data, response, error) in
            DispatchQueue.main.async {
                self.releaseVM.isLoading = false
            }

            if let error = error {
                onCheckResult(.failure(CheckerError.networkError(error)))
                DispatchQueue.main.async {
                    // progressIndicator?.close()
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                onCheckResult(.failure(CheckerError.invalidResponse))
                DispatchQueue.main.async {
                    self.releaseVM.error = CheckerError.invalidResponse
                    // progressIndicator?.close()
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let latestRelease = try decoder.decode(ReleaseInfo.self, from: data)

                // 使用 versionComparator 来判断是否有更新
                let hasUpdate = self.versionComparator?(currentVersion, latestRelease) ?? false
                let result: (ReleaseInfo?, Bool) = hasUpdate ? (latestRelease, true) : (nil, false)
                onCheckResult(.success((result.0, result.1)))

                DispatchQueue.main.async {
                    self.releaseVM.releaseInfo = latestRelease
                    self.releaseVM.hasUpdate = hasUpdate
                    // progressIndicator?.close()
                }
            } catch {
                onCheckResult(.failure(error))
                DispatchQueue.main.async {
                    self.releaseVM.error = error
                    // progressIndicator?.close()
                }
            }
        }
        task.resume()
    }

    private func showLoadingIndicator() -> NSWindow {
        let window = openSwiftUIWindow { win in
            ReleaseView(vm: self.releaseVM)
                .frame(width: self.width, height: self.height)
        }
        DispatchQueue.main.async {
            window.styleMask = [.closable, .titled]
            window.level = .floating
            window.center()
        }
        return window
    }

    private func buildAPIURL(from input: InputType) -> URL? {
        switch input {
        case .url(let url):
            let pathComponents = url.pathComponents.dropFirst(2).prefix(2)
            let repoPath = pathComponents.joined(separator: "/")
            guard !repoPath.isEmpty else { return nil }
            return URL(string: "https://api.github.com/repos/\(repoPath)/releases/latest")
        case .userRepo(let userRepo):
            return URL(string: "https://api.github.com/repos/\(userRepo)/releases/latest")
        case .gitUrl(let url):
            let pathComponents = url.absoluteString
                .replacingOccurrences(of: ".git", with: "")
                .components(separatedBy: "/")
                .dropFirst(3)

            let repoPath = pathComponents.joined(separator: "/")
            guard !repoPath.isEmpty else { return nil }
            return URL(string: "https://api.github.com/repos/\(repoPath)/releases/latest")
        }
    }

    private func getCurrentAppVersion() -> String? {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let shortVersionString = infoDictionary["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return shortVersionString
    }

    private func compareVersions(_ currentVersion: String, _ latestVersion: String) -> Bool {
        // 默认的版本比较：比较主版本号
        guard let currentMajor = Int(currentVersion.components(separatedBy: ".").first ?? "0"),
              let latestMajor = Int(latestVersion.components(separatedBy: ".").first ?? "0") else { return false }
        return latestMajor > currentMajor
    }
}



@available(macOS 10.15, *)
class ReleaseVM : ObservableObject {
    @Published var isLoading: Bool = false
    @Published var releaseInfo: ReleaseInfo? = nil
    @Published var error: (any Error)? = nil
    @Published var hasUpdate: Bool = false
}

@available(macOS 11, *)
struct ReleaseView : View {
    
    @StateObject var vm: ReleaseVM
    
    var body: some View {
        ZStack {
            if vm.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
            
            if let error = vm.error {
                Text(error.localizedDescription)
            }
            
            if let release = vm.releaseInfo {
                VStack(
                    spacing: 0
                ) {
                    HTMLWebView(htmlString:
                                    """
                                    <!DOCTYPE html>
                                    <html lang="en">
                                    <head>
                                      <meta charset="UTF-8">
                                      <meta name="viewport" content="width=device-width, initial-scale=1.0">
                                      <title>Markdown Preview</title>
                                      <!-- 使用最新版本的 Marked.js -->
                                      <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
                                      <style>
                                        body { font-family: Arial, sans-serif; margin: 20px; }
                                        pre, code { background-color: #f4f4f4; padding: 10px; border-radius: 5px; }
                                      </style>
                                    </head>
                                    <body>
                                      <div id="markdown-content"></div>
                                      <script>
                                        // 这里是你要渲染的 Markdown 内容
                                        const markdown = `# \(release.tagName) \n \(release.log)`;

                                        // 使用 Marked.js 的 parse 方法来将 Markdown 转换为 HTML
                                        document.getElementById('markdown-content').innerHTML = marked.parse(markdown);
                                      </script>
                                    </body>
                                    </html>
                                    """
                    )
//                    HTMLWebView(htmlString: """
//                                <!DOCTYPE html>
//                                <html>
//                                <head>
//                                </head>
//                                <body>
//                                    <h1>\(vm.releaseInfo?.tagName ?? "")</h1>
//                                    \(html)
//                                </body>
//                                </html>
//                            """)
                    if vm.hasUpdate {
                        Button(action: {
                            if let url = URL(string: release.htmlUrl) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Image(systemName: "arrowshape.up.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                        .padding(8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .padding(4)
                    }
                }
            }
            
        }
//        .frame(width: 400, height: 300)
    }
}

@available(macOS 10.15, *)
struct HTMLWebView: NSViewRepresentable {
    let htmlString: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 仅在需要时更新 HTML 内容
        if nsView.url == nil || nsView.url?.absoluteString != "about:blank" {
            nsView.loadHTMLString(htmlString, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
        }
    }
}
