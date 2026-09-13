import SwiftUI

@main struct PBCSongbookApp: App {
    @State private var store = SongbookStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Brand.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.autoUpdateIfNeeded() } }
                }
        }
    }
}

enum Brand {
    static let navy = Color(red: 0, green: 50/255, blue: 112/255)
    static let red = Color(red: 228/255, green: 33/255, blue: 37/255)
    static let accent = Color("AccentColor")
}

struct ChurchHeader: View {
    var body: some View {
        Image("ChurchLogo").resizable().scaledToFit().frame(maxWidth: 300)
            .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityLabel("Peniel Baptist Church")
    }
}

struct RootView: View {
    @Environment(SongbookStore.self) private var store
    var body: some View {
        @Bindable var store = store
        // The system TabView adopts Liquid Glass when built with Xcode 26 and run on iOS 26.
        // Earlier iOS versions retain their standard accessible native tab bar.
        TabView {
            NavigationStack { SongListView(favoritesOnly: false) }
                .tabItem { Label("Songbook", systemImage: "book.fill") }
            NavigationStack { SongListView(favoritesOnly: true) }
                .tabItem { Label("Favorites", systemImage: "heart") }
            NavigationStack { DownloadsView() }
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
        }
        .task { await store.loadSongsIfNeeded() }
        .alert("Songbook", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

struct SongListView: View {
    @Environment(SongbookStore.self) private var store
    let favoritesOnly: Bool
    @State private var query = ""
    @State private var category = "All books"
    @State private var showNumber = false
    @State private var number = ""
    @State private var numberFilter: Int?
    private var categories: [String] { Array(Set(store.songs.map(\.category).filter { !$0.isEmpty })).sorted() }
    private var filtered: [Song] {
        store.songs.filter {
            (!favoritesOnly || store.favorites.contains($0.id)) &&
            (category == "All books" || $0.category == category) &&
            (numberFilter == nil || $0.number == numberFilter) && $0.matches(query)
        }
    }
    var body: some View {
        List {
            if !favoritesOnly {
                Section {
                    ChurchHeader().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                    Text("A familiar songbook. Ready wherever you worship.")
                        .font(.subheadline).foregroundStyle(.secondary).listRowBackground(Color.clear)
                }.listRowSeparator(.hidden)
            }
            Section {
                Picker("Songbook", selection: $category) {
                    Text("All books").tag("All books")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                Button { showNumber = true } label: { Label("Go to song number", systemImage: "number.square") }
                if let numberFilter {
                    Button("Clear number filter: \(numberFilter)", systemImage: "xmark.circle") { self.numberFilter = nil }
                }
            }
            Section("\(filtered.count) songs") {
                if store.songs.isEmpty && store.isUpdating {
                    HStack {
                        Spacer()
                        ProgressView("Loading songs…")
                        Spacer()
                    }
                    .padding(.vertical, 28)
                }
                ForEach(filtered) { song in
                    NavigationLink { SongReaderView(song: song) } label: {
                        HStack(spacing: 14) {
                            Text(song.number.map(String.init) ?? "♪")
                                .font(.headline.monospacedDigit()).foregroundStyle(Brand.accent)
                                .frame(minWidth: 38, minHeight: 38)
                                .background(Brand.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                if !song.category.isEmpty { Text(song.category).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer(minLength: 0)
                            if store.favorites.contains(song.id) {
                                Image(systemName: "heart.fill").foregroundStyle(Brand.red).accessibilityLabel("Favorite")
                            }
                        }.padding(.vertical, 4)
                    }
                    .swipeActions { Button { store.toggleFavorite(song) } label: { Label("Favorite", systemImage: "heart") }.tint(Brand.red) }
                }
                if filtered.isEmpty && !store.isUpdating {
                    ContentUnavailableView(favoritesOnly && store.favorites.isEmpty ? "No favorites yet" : "No songs found",
                                           systemImage: favoritesOnly ? "heart" : "magnifyingglass",
                                           description: Text(favoritesOnly && store.favorites.isEmpty ? "Tap the heart on a song to save it here." : "Try another number, book, title, or lyric."))
                }
            }
        }
        .navigationTitle(favoritesOnly ? "Favorites" : "PBC Songbook")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Title, number, or lyrics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { AboutView() } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("About & Support")
            }
        }
        .alert("Go to song number", isPresented: $showNumber) {
            TextField("Song number", text: $number).keyboardType(.numberPad)
            Button("Find") { numberFilter = Int(number); query = "" }
                .disabled(Int(number) == nil)
            Button("Cancel", role: .cancel) { }
        } message: { Text("Some books share the same song numbers. Choose a book to narrow your results.") }
    }
}
