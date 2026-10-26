import SwiftUI
import Core

struct ServersPanel: View {
    @Bindable var model: AppModel
    @State private var editing: ConnectionProfile?
    @State private var adding = false
    @State private var pendingDelete: ConnectionProfile?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Servers").font(.headline)
                Spacer()
                Button { adding = true } label: { Label("Add server", systemImage: "plus") }
            }
            .padding(12)
            Divider()
            if model.servers.isEmpty {
                Text("No saved servers yet. Add one to reuse its credentials.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(24).frame(maxHeight: .infinity)
            } else {
                List(model.servers) { server in row(server) }
            }
        }
        .sheet(isPresented: $adding) { ServerEditor(model: model, existing: nil) }
        .sheet(item: $editing) { ServerEditor(model: model, existing: $0) }
        .confirmationDialog("Delete \(pendingDelete?.label ?? "server")?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let p = pendingDelete { model.deleteProfile(p) }
                pendingDelete = nil
            }
        } message: {
            Text("The saved password or passphrase is removed from the Keychain too.")
        }
    }

    private func row(_ server: ConnectionProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.label).fontWeight(.semibold)
                    if model.activeProfile?.id == server.id {
                        Text("In use").font(.caption2).padding(.horizontal, 5)
                            .background(.tint.opacity(0.25), in: Capsule())
                    }
                }
                Text("\(server.username)@\(server.host)\(server.port == 22 ? "" : ":\(server.port)")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Use") { model.use(server) }
            Button("Edit") { editing = server }
            Button(role: .destructive) { pendingDelete = server } label: { Image(systemName: "trash") }
                .help("Delete \(server.label)")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
    }
}

struct ServerEditor: View {
    @Environment(\.dismiss) private var dismiss
    let model: AppModel
    let existing: ConnectionProfile?

    @State private var label = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var useKey = false
    @State private var keyPath = ""
    @State private var secret = ""
    @State private var directory = ""
    @State private var status: Status = .idle
    @State private var hostKeyIssue: HostKeyIssue?
    @State private var pendingTarget: SFTPTarget?

    private enum Status: Equatable { case idle, testing, ok(String), failed(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(existing == nil ? "Add server" : "Edit server").font(.headline)
            TextField("Label", text: $label)
            HStack {
                TextField("Host", text: $host)
                TextField("Port", text: $port).frame(width: 70)
            }
            TextField("User name", text: $username)
            Picker("Authentication", selection: $useKey) {
                Text("Password").tag(false)
                Text("Key file").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden()
            if useKey {
                TextField("Key file path", text: $keyPath)
                SecureField(existing == nil ? "Key passphrase (optional)" : "Key passphrase (blank keeps saved)", text: $secret)
            } else {
                SecureField(existing == nil ? "Password" : "Password (blank keeps saved)", text: $secret)
            }
            TextField("Default directory (optional)", text: $directory)

            switch status {
            case .idle: EmptyView()
            case .testing: ProgressView("Testing…").controlSize(.small)
            case .ok(let message): Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed(let message): Label(message, systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.callout)
            }

            HStack {
                Button("Test Connection") { test() }.disabled(status == .testing)
                Button("Forget Host Key") { forgetHostKey() }
                    .help("Remove the saved key for this server so the next connection asks again")
                    .disabled(host.isEmpty)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20).frame(width: 460)
        .hostKeyDialog($hostKeyIssue, onTrust: trustAndTest)
        .onAppear(perform: load)
    }

    private func load() {
        guard let p = existing else { keyPath = model.defaultKeyPath; return }
        label = p.label; host = p.host; port = String(p.port); username = p.username
        directory = p.defaultDirectory ?? ""
        if case .key(let path) = p.auth { useKey = true; keyPath = path }
    }

    private func draft() -> ConnectionProfile {
        ConnectionProfile(id: existing?.id ?? UUID(), label: label.isEmpty ? host : label, host: host,
                          port: Int(port) ?? 0, username: username,
                          auth: useKey ? .key(path: keyPath) : .password,
                          defaultDirectory: directory.isEmpty ? nil : directory)
    }

    private func test() {
        let profile = draft()
        if let problem = profile.validationError { status = .failed(problem); return }
        let saved = existing.flatMap { model.profiles.secret(for: $0) }
        let target = profile.target(secret: secret.isEmpty ? saved : secret)
        status = .testing
        Task {
            switch await ConnectionTester.test(target, directory: profile.defaultDirectory) {
            case .success(let count): status = .ok("Connected. \(count) entries found.")
            case .failure(let failure):
                status = .failed(failure.description)
                if let issue = failure.hostKey { pendingTarget = target; hostKeyIssue = issue }
            }
        }
    }

    private func trustAndTest(_ fingerprint: HostKeyFingerprint) {
        guard let target = pendingTarget else { return }
        Task {
            if let failure = await model.trust(fingerprint, target: target) { status = .failed(failure.description) } else { test() }
        }
    }

    private func forgetHostKey() {
        KnownHosts.forget(host: host, port: Int(port) ?? 22)
        status = .ok("Host key forgotten. The next connection will ask again.")
    }

    private func save() {
        let profile = draft()
        if let problem = profile.validationError { status = .failed(problem); return }
        // Switching between password and key makes the old secret meaningless, so clear it.
        let authChanged = existing.map { ($0.auth == .password) != (profile.auth == .password) } ?? false
        model.saveProfile(profile, secret: secret.isEmpty ? (authChanged ? "" : nil) : secret)
        dismiss()
    }
}

extension View {
    /// Asks whether to trust an unknown server, or reports a changed host key (which is never overridable here).
    func hostKeyDialog(_ issue: Binding<HostKeyIssue?>, onTrust: @escaping (HostKeyFingerprint) -> Void) -> some View {
        alert(issue.wrappedValue.map(HostKeyDialogText.title) ?? "", isPresented: Binding(
            get: { issue.wrappedValue != nil }, set: { if !$0 { issue.wrappedValue = nil } }), presenting: issue.wrappedValue) { shown in
            if case .unknown(let fingerprint) = shown {
                Button("Trust") { onTrust(fingerprint) }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { shown in
            Text(HostKeyDialogText.message(shown))
        }
    }
}

private enum HostKeyDialogText {
    static func title(_ issue: HostKeyIssue) -> String {
        switch issue {
        case .unknown(let fp): return "Trust \(fp.hostLabel)?"
        case .changed(let fp): return "Host key for \(fp.hostLabel) changed"
        }
    }

    static func message(_ issue: HostKeyIssue) -> String {
        switch issue {
        case .unknown(let fp):
            return "This is the first connection to this server, so its identity can't be checked yet.\n\n\(fp.keyType) fingerprint:\n\(fp.sha256)\n\nTrust it only if you expect this server. If unsure, compare the fingerprint with your provider."
        case .changed(let fp):
            return "The server now presents a different key than the one you trusted:\n\n\(fp.sha256)\n\nThe server may have been reinstalled, or someone may be intercepting the connection. The connection was blocked. If you know the change is legitimate, use Forget Host Key in the server's Edit window and connect again."
        }
    }
}
