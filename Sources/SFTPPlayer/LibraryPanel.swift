import SwiftUI
import Core

struct LibraryPanel: View {
    let model: AppModel
    @Bindable var library: LibraryModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if library.hasServer {
                breadcrumbs
                Divider()
            }
            content
        }
        .task { await library.loadIfNeeded() }
        .hostKeyDialog($library.hostKeyIssue) { fingerprint in
            guard let target = library.target else { return }
            Task {
                if let failure = await model.trust(fingerprint, target: target) {
                    model.openError = failure.description
                } else {
                    await library.reload()
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            TextField("Search this folder", text: $library.query).textFieldStyle(.roundedBorder)
            Menu {
                Picker("Sort", selection: $library.sort) {
                    Text("Name (A–Z)").tag(LibrarySort.nameAscending)
                    Text("Name (Z–A)").tag(LibrarySort.nameDescending)
                    Text("Last updated (newest)").tag(LibrarySort.modifiedNewest)
                    Text("Last updated (oldest)").tag(LibrarySort.modifiedOldest)
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton).fixedSize().help("Sort")
            Button { Task { await library.reload() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless).help("Refresh").disabled(!library.hasServer)
        }
        .padding(10)
        .disabled(!library.hasServer)
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(library.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 1 { Text("/").foregroundStyle(.secondary).accessibilityHidden(true) }
                    Button(crumb.name) { Task { await library.load(crumb.path) } }
                        .buttonStyle(.plain).foregroundStyle(Theme.gold)
                        .accessibilityLabel(crumb.path == "/" ? "Root folder" : "Folder \(crumb.name)")
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
        }
    }

    @ViewBuilder private var content: some View {
        if !library.hasServer {
            message("Choose a server under Servers and press Use, or open a video by URL.")
        } else if let error = library.errorMessage {
            VStack(spacing: 10) {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                Button("Retry") { Task { await library.reload() } }
            }
            .padding(24).frame(maxHeight: .infinity)
        } else if library.isLoading && library.entries.isEmpty {
            ProgressView().frame(maxHeight: .infinity)
        } else if library.visibleEntries.isEmpty {
            message(library.query.isEmpty ? "This folder is empty." : "Nothing matches \"\(library.query)\".")
        } else {
            List(library.visibleEntries, id: \.name) { entry in row(entry) }
                .overlay(alignment: .top) { if library.isLoading { ProgressView().controlSize(.small).padding(6) } }
        }
        if let error = model.openError, !model.showOpenSheet {
            Text("Playback failed: \(error)").font(.callout).foregroundStyle(.red).padding(10)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(24).frame(maxHeight: .infinity)
    }

    private func row(_ entry: RemoteEntry) -> some View {
        let playable = entry.isDirectory || entry.isVideo
        return Button {
            if entry.isDirectory { Task { await library.load(library.childPath(entry.name)) } } else { model.playFromLibrary(entry) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: entry.isDirectory ? "folder.fill" : entry.isVideo ? "film" : "doc")
                    .foregroundStyle(entry.isDirectory ? Theme.gold : .secondary).frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name).lineLimit(1).truncationMode(.middle)
                    Text(detail(entry)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!playable)
        .opacity(playable ? 1 : 0.5)
        .help(entry.name)
    }

    private func detail(_ entry: RemoteEntry) -> String {
        var parts: [String] = []
        if !entry.isDirectory { parts.append(ByteCountFormatter.string(fromByteCount: Int64(entry.size), countStyle: .file)) }
        if let date = entry.modified { parts.append(date.formatted(date: .abbreviated, time: .omitted)) }
        return parts.joined(separator: " · ")
    }
}
