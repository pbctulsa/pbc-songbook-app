import Foundation

struct Song: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var title: String
    var number: Int?
    var author: String
    var category: String
    var songKey: String
    var lyrics: String

    var displayTitle: String {
        guard let number, !title.hasPrefix("\(number).") else { return title }
        return "\(number). \(title)"
    }
    var webURL: URL { URL(string: "https://www.pbctulsa.org/songbook")!.appendingPathComponent(id) }
    var shareText: String { "\(displayTitle)\n\n\(lyrics)\n\n\(webURL.absoluteString)" }
    var fields: [String: String] {
        ["title": title, "author": author, "category": category, "songKey": songKey, "lyrics": lyrics]
    }
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        let haystack = "\(number.map(String.init) ?? "") \(title) \(lyrics) \(category)"
        return words.allSatisfy { haystack.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
    static func ordered(_ songs: [Song]) -> [Song] {
        songs.sorted {
            if $0.number != $1.number { return ($0.number ?? .max) < ($1.number ?? .max) }
            if $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return $0.id < $1.id
        }
    }
}

struct Catalog: Codable, Sendable {
    let downloadedAt: Date
    let songs: [Song]
    static func decodeAPI(_ data: Data, now: Date = Date()) throws -> Catalog {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = object["songs"] as? [[String: Any]],
              let total = object["total"] as? Int, total == rows.count, total > 0 else {
            throw SongbookError.invalidCatalog
        }
        func value(_ row: [String: Any], _ keys: [String]) -> String {
            for key in keys {
                if let text = row[key] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let n = row[key] as? Int { return String(n) }
            }
            return ""
        }
        let songs = try rows.map { row -> Song in
            let id = value(row, ["id", "song_id", "slug"])
            let title = value(row, ["title", "song_title", "name"])
            let lyrics = value(row, ["lyrics_text", "lyrics", "song_lyrics", "body", "content", "text"])
            guard !id.isEmpty, !title.isEmpty, !lyrics.isEmpty else { throw SongbookError.invalidCatalog }
            return Song(id: id, title: title,
                        number: Int(value(row, ["number", "song_number", "song_no", "hymn_number"])),
                        author: value(row, ["author", "artist", "writer", "composer"]),
                        category: value(row, ["category", "book", "song_type", "type"]),
                        songKey: value(row, ["song_key", "key"]), lyrics: lyrics)
        }
        guard Set(songs.map(\.id)).count == songs.count else { throw SongbookError.invalidCatalog }
        return Catalog(downloadedAt: now, songs: Song.ordered(songs))
    }
}

enum SongbookError: LocalizedError {
    case invalidCatalog, server(Int)
    var errorDescription: String? {
        switch self {
        case .invalidCatalog: "The songbook update was incomplete. Your saved songs have been kept."
        case .server(let code): "The church server could not complete the request (\(code)). Please try again later."
        }
    }
}

struct EditDraft: Codable, Equatable, Identifiable {
    var id: String { song.id }
    let song: Song
    var title: String
    var author: String
    var category: String
    var songKey: String
    var lyrics: String
    var note = ""
    var name = ""
    var email = ""
    init(song: Song) {
        self.song = song; title = song.title; author = song.author
        category = song.category; songKey = song.songKey; lyrics = song.lyrics
    }
    var suggestedFields: [String: String] {
        ["title": title, "author": author, "category": category, "songKey": songKey, "lyrics": lyrics]
            .mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    var hasChanges: Bool { suggestedFields != song.fields || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var validEmail: Bool {
        email.isEmpty || email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
    var canSubmit: Bool { hasChanges && validEmail && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func payload() throws -> Data {
        var object: [String: Any] = ["songId": song.id, "songTitle": song.title,
                                    "originalFields": song.fields, "suggestedFields": suggestedFields,
                                    "submitterName": name, "submitterEmail": email, "note": note]
        if let number = song.number { object["songNumber"] = number }
        return try JSONSerialization.data(withJSONObject: object)
    }
}
