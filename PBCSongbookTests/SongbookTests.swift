import XCTest
@testable import PBCSongbook

final class SongbookTests: XCTestCase {
    private func song(id: String = "one", number: Int? = 12, category: String = "Houbung La") -> Song {
        Song(id: id, title: "Lungset", number: number, author: "", category: category, songKey: "", lyrics: "Verse 1\nNgailutna\n\nVerse 2\nPakai")
    }
    func testSearchFindsLyricsAndMultipleWords() {
        XCTAssertTrue(song().matches("12 ngailutna"))
        XCTAssertTrue(song().matches("LUNGSET"))
        XCTAssertTrue(song().matches(""))
        XCTAssertFalse(song().matches("missing"))
    }
    func testNumberedSongsSortBeforeUnnumberedAndKeepDifferentBooks() {
        let input = [song(id: "a", number: nil), song(id: "b", number: 12), song(id: "c", number: 2), song(id: "d", number: 12, category: "KCN")]
        XCTAssertEqual(Song.ordered(input).map(\.id), ["c", "b", "d", "a"])
    }
    func testAPIAliasesAndNulls() throws {
        let data = Data(#"{"songs":[{"id":"abc","title":"Song","number":null,"song_number":42,"book":"KCN","lyrics_text":null,"lyrics":"Verse 1\nWords"}],"total":1}"#.utf8)
        let result = try Catalog.decodeAPI(data)
        XCTAssertEqual(result.songs.first?.number, 42)
        XCTAssertEqual(result.songs.first?.category, "KCN")
        XCTAssertEqual(result.songs.first?.lyrics, "Verse 1\nWords")
    }
    func testRejectsPartialEmptyAndDuplicateCatalogs() {
        for json in [#"{"songs":[],"total":0}"#, #"{"songs":[],"total":2}"#, #"{"songs":[{"id":"a","title":"X","lyrics":"Y"},{"id":"a","title":"X","lyrics":"Y"}],"total":2}"#] {
            XCTAssertThrowsError(try Catalog.decodeAPI(Data(json.utf8)))
        }
    }
    func testSharePreservesFormattingAndSongLink() {
        XCTAssertTrue(song().shareText.contains("12. Lungset\n\nVerse 1\nNgailutna"))
        XCTAssertTrue(song().shareText.contains("https://www.pbctulsa.org/songbook/one"))
    }
    func testSuggestionKeepsOriginalSnapshotAndUsesExistingAPIContract() throws {
        var draft = EditDraft(song: song())
        XCTAssertFalse(draft.canSubmit)
        draft.lyrics = "Corrected lyrics"; draft.email = "member@example.com"
        XCTAssertTrue(draft.canSubmit)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: draft.payload()) as? [String: Any])
        XCTAssertEqual(payload["songId"] as? String, "one")
        XCTAssertEqual((payload["originalFields"] as? [String: String])?["lyrics"], song().lyrics)
        XCTAssertEqual((payload["suggestedFields"] as? [String: String])?["lyrics"], "Corrected lyrics")
        draft.email = "invalid"; XCTAssertFalse(draft.canSubmit)
    }
    @MainActor func testFirstLaunchAutomaticallyDownloadsAndPersistsCatalog() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let expected = song()
        let store = SongbookStore(directory: directory, defaults: defaults, includeBundledCatalog: false) {
            Catalog(downloadedAt: Date(), songs: [expected])
        }

        await store.loadSongsIfNeeded()

        XCTAssertEqual(store.songs, [expected])
        let saved = try JSONDecoder().decode(
            Catalog.self,
            from: Data(contentsOf: directory.appendingPathComponent("catalog.json"))
        )
        XCTAssertEqual(saved.songs, [expected])
    }
    func testBundledCatalogContainsUniqueReadableSongs() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "catalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(catalog.songs.count, 1000)
        XCTAssertEqual(Set(catalog.songs.map(\.id)).count, catalog.songs.count)
        XCTAssertTrue(catalog.songs.allSatisfy { !$0.lyrics.isEmpty && !$0.title.isEmpty })
    }
}
