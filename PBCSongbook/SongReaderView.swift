import SwiftUI
import UIKit

struct SongReaderView: View {
    @Environment(SongbookStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State var song: Song
    let sequence: [Song]
    @AppStorage("textSize") private var textSize = 24.0
    @AppStorage("readingTheme") private var theme = "System"
    @AppStorage("keepAwake") private var keepAwake = false
    @ScaledMetric(relativeTo: .body) private var fontScale = 1.0
    @State private var settings = false
    @State private var sharing = false
    @State private var suggesting = false
    @State private var copied = false
    private var index: Int { sequence.firstIndex(where: { $0.id == song.id }) ?? 0 }
    private var background: Color { theme == "Sepia" ? Color(red: 0.97, green: 0.94, blue: 0.86) : Color(uiColor: .systemBackground) }
    private var scheme: ColorScheme? { theme == "Dark" ? .dark : (theme == "Light" || theme == "Sepia" ? .light : nil) }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(song.category.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(song.displayTitle).font(.largeTitle.weight(.bold)).foregroundStyle(Brand.accent)
                        Label("Available offline", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                        if !song.songKey.isEmpty { Text(song.songKey).font(.subheadline).foregroundStyle(.secondary) }
                        if !song.author.isEmpty { Text(song.author).font(.subheadline).foregroundStyle(.secondary) }
                    }.id("top")
                    Text(song.lyrics).font(.system(size: textSize * fontScale, design: .serif))
                        .lineSpacing(8).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if copied { Label("Lyrics copied", systemImage: "checkmark").font(.callout).foregroundStyle(Brand.accent) }
                }.padding(24)
            }
            .onChange(of: song.id) { _, _ in proxy.scrollTo("top", anchor: .top) }
        }
        .background(background)
        .preferredColorScheme(scheme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { store.toggleFavorite(song) } label: {
                    Image(systemName: store.favorites.contains(song.id) ? "heart.fill" : "heart")
                        .foregroundStyle(store.favorites.contains(song.id) ? Brand.red : Brand.accent)
                }.accessibilityLabel(store.favorites.contains(song.id) ? "Remove favorite" : "Add favorite")
                Button { settings = true } label: { Image(systemName: "textformat.size") }.accessibilityLabel("Reading settings")
                Menu {
                    Button("Copy lyrics", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = song.shareText; copied = true
                        UIAccessibility.post(notification: .announcement, argument: "Lyrics copied")
                    }
                    Button("Share song", systemImage: "square.and.arrow.up") { sharing = true }
                    Button("Suggest an edit", systemImage: "pencil") { suggesting = true }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Song actions")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Toggle(isOn: $keepAwake) { Label("Keep awake", systemImage: "sun.max") }.font(.caption)
                Divider().frame(height: 24)
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 44) }
                    .disabled(index == 0).accessibilityLabel("Previous song")
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 44) }
                    .disabled(index >= sequence.count - 1).accessibilityLabel("Next song")
            }.padding(.horizontal, 16).padding(.vertical, 8).readingGlass().padding(.horizontal, 16).padding(.bottom, 4)
        }
        .sheet(isPresented: $settings) {
            NavigationStack {
                Form {
                    Section("Text size") { Slider(value: $textSize, in: 18...40, step: 1) { Text("Text size") }; Text("Preview of song lyrics").font(.system(size: textSize, design: .serif)) }
                    Section("Appearance") { Picker("Appearance", selection: $theme) { ForEach(["System", "Light", "Sepia", "Dark"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.inline).labelsHidden() }
                }.navigationTitle("Reading settings").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { settings = false } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sharing) { ShareSongView(song: song) }
        .sheet(isPresented: $suggesting) { SuggestionView(draft: store.drafts[song.id] ?? EditDraft(song: song)) }
        .onAppear { updateAwake() }
        .onChange(of: keepAwake) { _, _ in updateAwake() }
        .onChange(of: scenePhase) { _, _ in updateAwake() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
    private func updateAwake() { UIApplication.shared.isIdleTimerDisabled = keepAwake && scenePhase == .active }
    private func move(_ offset: Int) {
        let next = index + offset
        guard sequence.indices.contains(next) else { return }
        song = sequence[next]; copied = false
    }
}

private struct ReadingGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}
extension View { fileprivate func readingGlass() -> some View { modifier(ReadingGlass()) } }

struct ShareSongView: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @State private var useLink = false
    @State private var showSystemShare = false
    var body: some View {
        NavigationStack {
            Form {
                Section { Label(song.displayTitle, systemImage: "book.fill").font(.headline) }
                Section {
                    Picker("Share format", selection: $useLink) { Text("Lyrics").tag(false); Text("Song link").tag(true) }.pickerStyle(.segmented)
                    Text(useLink ? song.webURL.absoluteString : song.shareText).font(.body).textSelection(.enabled)
                }
                Section { Button("Share…", systemImage: "square.and.arrow.up") { showSystemShare = true } }
            }.navigationTitle("Share song").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }.sheet(isPresented: $showSystemShare) {
            ActivitySheet(items: useLink ? [song.webURL] : [song.shareText])
        }
    }
}
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
