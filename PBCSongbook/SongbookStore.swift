import Foundation
import Observation
import Network

@MainActor @Observable final class SongbookStore {
    private(set) var songs: [Song] = []
    private(set) var downloadedAt: Date?
    private(set) var isUpdating = false
    private(set) var isOnline = true
    private(set) var isWiFi = false
    private(set) var favorites: Set<String> = []
    private(set) var drafts: [String: EditDraft] = [:]
    var message: String?
    var lastUpdateMessage: String?
    private let directory: URL
    private let monitor = NWPathMonitor()
    private let defaults: UserDefaults
    private let session: URLSession
    private let catalogProvider: (@Sendable () async throws -> Catalog)?
    private var lastAutomaticAttempt: Date?

    init(directory: URL? = nil, defaults: UserDefaults = .standard, session: URLSession = .shared,
         includeBundledCatalog: Bool = true,
         catalogProvider: (@Sendable () async throws -> Catalog)? = nil) {
        self.defaults = defaults; self.session = session; self.catalogProvider = catalogProvider
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("PBCSongbook", isDirectory: true)
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        } catch {
            message = "The songbook storage folder could not be opened: \(error.localizedDescription)"
        }

        let savedURL = self.directory.appendingPathComponent("catalog.json")
        if FileManager.default.fileExists(atPath: savedURL.path) {
            do {
                let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: savedURL))
                guard !catalog.songs.isEmpty else { throw SongbookError.invalidCatalog }
                songs = Song.ordered(catalog.songs); downloadedAt = catalog.downloadedAt
            } catch {
                message = "The saved songbook could not be opened. Downloading a fresh copy."
            }
        }

        if songs.isEmpty, includeBundledCatalog,
           let bundledURL = Bundle.main.url(forResource: "catalog", withExtension: "json"),
           let data = try? Data(contentsOf: bundledURL),
           let catalog = try? JSONDecoder().decode(Catalog.self, from: data),
           !catalog.songs.isEmpty {
            songs = Song.ordered(catalog.songs); downloadedAt = catalog.downloadedAt
        }

        let draftsURL = self.directory.appendingPathComponent("drafts.json")
        if FileManager.default.fileExists(atPath: draftsURL.path) {
            do {
                drafts = try JSONDecoder().decode([String: EditDraft].self, from: Data(contentsOf: draftsURL))
            } catch {
                message = "Your saved edit drafts could not be opened: \(error.localizedDescription)"
            }
        }
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let wifi = path.usesInterfaceType(.wifi) && !path.isExpensive && !path.isConstrained
            Task { @MainActor [weak self] in
                self?.isOnline = online; self?.isWiFi = wifi
                await self?.autoUpdateIfNeeded()
            }
        }
        monitor.start(queue: DispatchQueue(label: "org.pbctulsa.songbook.network"))
    }

    func toggleFavorite(_ song: Song) {
        if favorites.contains(song.id) { favorites.remove(song.id) } else { favorites.insert(song.id) }
        defaults.set(Array(favorites), forKey: "favorites")
    }
    func saveDraft(_ draft: EditDraft) throws {
        var next = drafts; next[draft.id] = draft
        try persist(next, name: "drafts.json"); drafts = next
    }
    func removeDraft(_ id: String) throws {
        var next = drafts; next.removeValue(forKey: id)
        try persist(next, name: "drafts.json"); drafts = next
    }
    private func persist<T: Encodable>(_ value: T, name: String) throws {
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func updateCatalog() async {
        guard !isUpdating else { return }
        isUpdating = true; lastUpdateMessage = nil
        defer { isUpdating = false }
        do {
            let catalog: Catalog
            if let catalogProvider {
                catalog = try await catalogProvider()
            } else {
                var request = URLRequest(url: URL(string: "https://www.pbctulsa.org/api/songs")!)
                request.timeoutInterval = 45; request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw SongbookError.server((response as? HTTPURLResponse)?.statusCode ?? 0)
                }
                catalog = try Catalog.decodeAPI(data)
            }
            try persist(catalog, name: "catalog.json")
            songs = catalog.songs; downloadedAt = catalog.downloadedAt
            lastUpdateMessage = "All \(songs.count) songs are saved for offline use."
        } catch {
            lastUpdateMessage = "Update unsuccessful. Your offline songs are still available. \(error.localizedDescription)"
        }
    }
    func loadSongsIfNeeded() async {
        guard songs.isEmpty else { return }
        await updateCatalog()
        if songs.isEmpty, lastUpdateMessage != nil {
            message = "Songs could not be loaded. Check your connection and try again from Downloads."
        }
    }
    func autoUpdateIfNeeded() async {
        guard defaults.bool(forKey: "wifiUpdates"), isWiFi,
              Date().timeIntervalSince(downloadedAt ?? .distantPast) > 86400,
              Date().timeIntervalSince(lastAutomaticAttempt ?? .distantPast) > 3600 else { return }
        lastAutomaticAttempt = Date()
        await updateCatalog()
    }
    func submit(_ draft: EditDraft) async throws {
        guard draft.canSubmit else { return }
        try saveDraft(draft)
        var request = URLRequest(url: URL(string: "https://www.pbctulsa.org/api/song-edit-suggestions")!)
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try draft.payload()
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SongbookError.server((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any], body["ok"] as? Bool == true else {
            throw SongbookError.server(0)
        }
        do { try removeDraft(draft.id) }
        catch { drafts.removeValue(forKey: draft.id); message = "Suggestion received, but its saved draft could not be removed. Do not submit it again." }
    }
}
