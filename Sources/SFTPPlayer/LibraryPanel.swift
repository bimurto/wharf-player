import SwiftUI
import Core

struct LibraryPanel: View {
    let model: AppModel
    @Bindable var library: LibraryModel
    @State private var selection: RemoteEntry.ID?

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
            table
                .overlay(alignment: .top) { if library.isLoading { ProgressView().controlSize(.small).padding(6) } }
        }
        if let error = model.openError, !model.showOpenSheet {
            Text("Playback failed: \(error)").font(.callout).foregroundStyle(.red).padding(10)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(24).frame(maxHeight: .infinity)
    }

    /// Name, Size and Updated columns; a header click sorts by it. A single click opens the entry.
    private var table: some View {
        Table(library.visibleEntries, selection: $selection, sortOrder: sortOrder) {
            TableColumn("Name", value: \.name) { entry in
                let playable = entry.isDirectory || entry.isVideo
                HStack(spacing: 6) {
                    Image(systemName: entry.isDirectory ? "folder.fill" : entry.isVideo ? "film" : "doc")
                        .foregroundStyle(entry.isDirectory ? Theme.gold : .secondary).frame(width: 18)
                    Text(entry.name).lineLimit(1).truncationMode(.middle)
                }
                .opacity(playable ? 1 : 0.5)
                .help(entry.name)
            }
            .width(min: 140, ideal: 200)
            TableColumn("Size", value: \.size) { entry in
                Text(entry.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: Int64(entry.size), countStyle: .file))
                    .monospacedDigit().foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 56, ideal: 68, max: 80)
            TableColumn("Updated", value: \.modifiedSortKey) { entry in
                Text(entry.modified?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150, max: 170)
        }
        .alternatingRowBackgrounds(.disabled)
        .onChange(of: selection) {
            guard let name = selection else { return }
            selection = nil
            guard let entry = library.visibleEntries.first(where: { $0.name == name }) else { return }
            if entry.isDirectory {
                Task { await library.load(library.childPath(entry.name)) }
            } else if entry.isVideo {
                model.playFromLibrary(entry)
            }
        }
    }

    /// Bridges the table's header sort to `library.sort`, which keeps folders first and natural name order.
    private var sortOrder: Binding<[KeyPathComparator<RemoteEntry>]> {
        Binding {
            let order: SortOrder = library.sort.ascending ? .forward : .reverse
            switch library.sort.column {
            case .name: return [KeyPathComparator(\.name, order: order)]
            case .size: return [KeyPathComparator(\.size, order: order)]
            case .modified: return [KeyPathComparator(\.modifiedSortKey, order: order)]
            }
        } set: { comparators in
            guard let first = comparators.first else { return }
            let column: LibraryColumn = switch first.keyPath {
            case \RemoteEntry.size: .size
            case \RemoteEntry.modifiedSortKey: .modified
            default: .name
            }
            library.sort = LibrarySort(column: column, ascending: first.order == .forward)
        }
    }
}
