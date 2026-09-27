import Foundation
import Observation

/// Looks for a newer release on GitHub at launch and once a day. Nothing about this Mac is sent;
/// it only reads the latest release's version and page.
@Observable
final class UpdateChecker {
    struct Release: Equatable {
        let version: String
        let page: URL
    }

    /// The newest release, when it's newer than this build.
    private(set) var available: Release?

    let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    static let feed = URL(string: "https://api.github.com/repos/geonhwiii/pokove/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/geonhwiii/pokove/releases/latest")!
    private static let interval: TimeInterval = 24 * 60 * 60

    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                guard (try? await Task.sleep(for: .seconds(Self.interval))) != nil else { return }
            }
        }
    }

    func check() async {
        #if DEBUG
        // `defaults write com.geonhwiii.pokove debugLatestVersion 9.9` pretends a release is out.
        if let version = UserDefaults.standard.string(forKey: "debugLatestVersion") {
            available = Self.isNewer(version, than: current) ? Release(version: version, page: Self.releasesPage) : nil
            return
        }
        #endif
        var request = URLRequest(url: Self.feed, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("pokove/\(current)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let latest = try? JSONDecoder().decode(Latest.self, from: data) else { return }
        let version = latest.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        available = Self.isNewer(version, than: current) ? Release(version: version, page: latest.html_url) : nil
    }

    private struct Latest: Decodable {
        let tag_name: String
        let html_url: URL
    }

    /// Compares dotted versions number by number, so 1.10 is newer than 1.9.
    nonisolated static func isNewer(_ version: String, than other: String) -> Bool {
        let parts = { (text: String) in text.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let a = parts(version), b = parts(other)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0, y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}
