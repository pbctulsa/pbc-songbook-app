import SwiftUI

struct DownloadsView: View {
    @Environment(SongbookStore.self) private var store
    @AppStorage("wifiUpdates") private var wifiUpdates = false
    @State private var selectedDraft: EditDraft?
    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "book.closed.fill").font(.system(size: 48)).foregroundStyle(Brand.accent)
                    Text(store.songs.isEmpty ? "Download your songbook" : "Songbook downloaded").font(.title2.bold())
                    Text("\(store.songs.count) songs available offline").foregroundStyle(.secondary)
                    if let date = store.downloadedAt { Text("Catalog saved \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
                    if store.isUpdating { ProgressView("Downloading songs…") }
                    Button { Task { await store.updateCatalog() } } label: { Text("Check for updates").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).disabled(store.isUpdating)
                }.frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            Section {
                Label("Keep singing without Wi-Fi or mobile data.", systemImage: "checkmark.circle")
                if !store.isOnline { Label("You're offline. Your saved songs are ready.", systemImage: "wifi.slash") }
                Toggle("Download updates on Wi-Fi", isOn: $wifiUpdates)
            } footer: { Text("When enabled, the app checks for updates while open on Wi-Fi. Manual updates can use mobile data. Updates replace the catalog only after a complete download.") }
            if let message = store.lastUpdateMessage { Section { Text(message).font(.callout) } }
            if !store.drafts.isEmpty {
                Section("Saved edit drafts") {
                    ForEach(store.drafts.values.sorted { $0.song.displayTitle < $1.song.displayTitle }) { draft in
                        Button { selectedDraft = draft } label: { Label(draft.song.displayTitle, systemImage: "pencil") }
                    }
                }
            }
        }.navigationTitle("Downloads")
            .onChange(of: wifiUpdates) { _, enabled in if enabled { Task { await store.autoUpdateIfNeeded() } } }
            .sheet(item: $selectedDraft) { SuggestionView(draft: $0) }
    }
}

struct SuggestionView: View {
    @Environment(SongbookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: EditDraft
    @State private var submitting = false
    @State private var error: String?
    @State private var sent = false
    @State private var discard = false
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(draft.song.displayTitle).font(.headline); Text("Suggestions are reviewed before the songbook is updated.").font(.subheadline).foregroundStyle(.secondary) }
                Section("Suggested correction") {
                    TextField("Title", text: $draft.title)
                    TextField("Author", text: $draft.author)
                    TextField("Book or category", text: $draft.category)
                    TextField("Key", text: $draft.songKey)
                }
                Section("Lyrics") { TextEditor(text: $draft.lyrics).frame(minHeight: 260).accessibilityLabel("Corrected lyrics") }
                Section("Reason (optional)") { TextField("Tell us what needs changing", text: $draft.note, axis: .vertical).lineLimit(3...6) }
                Section {
                    TextField("Name", text: $draft.name).textContentType(.name)
                    TextField("Email for follow-up", text: $draft.email).keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !draft.validEmail { Text("Enter a valid email or leave it blank.").foregroundStyle(.red) }
                } header: { Text("Your details (optional)") } footer: { Text("Your correction and any details you enter are sent to Peniel Baptist Church only when you tap Submit. Drafts are saved on this device.") }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if submitting { Section { ProgressView("Submitting for review…") } }
                Section { Button("Discard draft", role: .destructive) { discard = true }.disabled(submitting) }
            }.navigationTitle("Suggest an edit").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Save & Close") { saveAndClose() }.disabled(submitting) }
                    ToolbarItem(placement: .confirmationAction) { Button("Submit") { Task { await submit() } }.disabled(!draft.canSubmit || submitting) }
                }
                .onChange(of: draft) { _, value in
                    guard !sent else { return }
                    do { try store.saveDraft(value) } catch { self.error = "Draft could not be saved: \(error.localizedDescription)" }
                }
                .interactiveDismissDisabled()
                .alert("Suggestion submitted", isPresented: $sent) { Button("Done") { dismiss() } } message: { Text("Thank you. Your correction has been sent for review.") }
                .confirmationDialog("Discard this saved draft?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Discard draft", role: .destructive) {
                        do { try store.removeDraft(draft.id); dismiss() } catch { self.error = error.localizedDescription }
                    }
                }
        }
    }
    private func saveAndClose() {
        do { if draft.hasChanges || !draft.email.isEmpty || !draft.name.isEmpty { try store.saveDraft(draft) }; dismiss() }
        catch { self.error = "Draft could not be saved. \(error.localizedDescription)" }
    }
    private func submit() async {
        submitting = true; error = nil
        defer { submitting = false }
        do { try await store.submit(draft); sent = true }
        catch {
            self.error = "Could not confirm submission. Your draft is saved. Check your connection before trying again. If the request timed out, it may already have arrived. \(error.localizedDescription)"
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    ChurchHeader()
                    Text("PBC Songbook").font(.largeTitle.weight(.bold)).foregroundStyle(Brand.accent)
                    Text("A familiar songbook for worship, at church and wherever you gather.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            Section("Made with purpose") {
                Text("A ministry of Peniel Baptist Church")
                Text("Designed & developed by James").foregroundStyle(.secondary)
            }
            Section {
                Label("Support the ministry", systemImage: "heart").font(.headline).foregroundStyle(Brand.accent)
                Text("Your generosity supports the ministry of Peniel Baptist Church.").foregroundStyle(.secondary)
                Link(destination: URL(string: "https://pbctulsa.churchcenter.com/giving")!) {
                    Label("Donate to Peniel Baptist Church", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
                Text("Opens our church giving page").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Link(destination: URL(string: "https://www.pbctulsa.org/contact")!) { Label("Contact & feedback", systemImage: "envelope") }
                Link(destination: URL(string: "https://www.pbctulsa.org")!) { Label("Church website", systemImage: "globe") }
                NavigationLink { PrivacyView() } label: { Label("Privacy & acknowledgments", systemImage: "doc.text") }
            }
            Section { Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("About & Support").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("On your device") { Text("Songs, favorites, reading preferences, and unsent edit drafts are stored on your device. This app includes no advertising or analytics SDKs and requires no account.") }
            Section("When you connect") { Text("Songbook updates contact the church website. Its hosting provider may process ordinary request information such as your IP address. Suggested edits send the original and proposed song fields, your note, and any optional name or email you provide to the church for review.") }
            Section("Sharing and giving") { Text("You choose what to share and where through iOS. Giving opens the church's external Church Center page. Donations and payment details are handled there, not by this app.") }
            Section("Acknowledgments") { Text("Song content comes from Peniel Baptist Church's published songbook. Song lyrics remain the property of their respective rights holders. Church branding is provided by Peniel Baptist Church.") }
            Section {
                Link("View the full privacy policy", destination: URL(string: "https://www.pbctulsa.org/songbook/privacy")!)
                Link("Contact the church about your information", destination: URL(string: "https://www.pbctulsa.org/contact")!)
            }
        }.navigationTitle("Privacy & acknowledgments").navigationBarTitleDisplayMode(.inline)
    }
}
