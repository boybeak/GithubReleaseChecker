// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

public struct ReleaseInfo: Decodable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String // 下载链接地址

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
    }
}

public class GithubReleaseChecker : @unchecked Sendable {
    public typealias CheckResultCallback = @Sendable (Result<(newVersion: ReleaseInfo?, hasUpdate: Bool), Error>) -> Void

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
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

    public func checkUpdate(for input: InputType, onCheckResult: @escaping CheckResultCallback) {
        guard let currentVersion = getCurrentAppVersion() else {
            onCheckResult(.failure(CheckerError.cantGetCurrentVersion))
            return
        }

        guard let apiURL = buildAPIURL(from: input) else {
            onCheckResult(.failure(CheckerError.invalidInput))
            return
        }

        let task = session.dataTask(with: apiURL) { (data, response, error) in
            if let error = error {
                onCheckResult(.failure(CheckerError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                onCheckResult(.failure(CheckerError.invalidResponse))
                return
            }

            do {
                let decoder = JSONDecoder()
//                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let releases = try decoder.decode([ReleaseInfo].self, from: data)

                guard let latestRelease = releases.first else {
                    onCheckResult(.failure(CheckerError.noReleases))
                    return
                }

                let hasUpdate = self.compareVersions(currentVersion, latestRelease.tagName)
                let result:(ReleaseInfo?, Bool) = hasUpdate ? (latestRelease, true) : (nil, false)
                onCheckResult(.success((result.0,result.1)))
            } catch {
                onCheckResult(.failure(error))
            }
        }
        task.resume()
    }

    private func buildAPIURL(from input: InputType) -> URL? {
        switch input {
        case .url(let url):
            let pathComponents = url.pathComponents.dropFirst(2).prefix(2)
            let repoPath = pathComponents.joined(separator: "/")
            guard !repoPath.isEmpty else { return nil }
            return URL(string: "https://api.github.com/repos/\(repoPath)/releases")
        case .userRepo(let userRepo):
            return URL(string: "https://api.github.com/repos/\(userRepo)/releases")
        case .gitUrl(let url):
            let pathComponents = url.absoluteString
                .replacingOccurrences(of: ".git", with: "")
                .components(separatedBy: "/")
                .dropFirst(3)

            let repoPath = pathComponents.joined(separator: "/")
            guard !repoPath.isEmpty else { return nil }
            return URL(string: "https://api.github.com/repos/\(repoPath)/releases")
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
        // 实现版本比较逻辑，推荐使用 swift-semver 等库
        // 简单的主要版本比较示例：
        guard let currentMajor = Int(currentVersion.components(separatedBy: ".").first ?? "0"),
              let latestMajor = Int(latestVersion.components(separatedBy: ".").first ?? "0") else { return false }
        return latestMajor > currentMajor
    }
}
