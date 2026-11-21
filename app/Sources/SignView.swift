import SwiftUI
import UniformTypeIdentifiers

struct SignView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    let app: LibraryApp

    @State private var name = ""
    @State private var bundleID = ""
    @State private var version = ""
    @State private var minIOS = ""
    @State private var iconURL: URL?
    @State private var iconImage: UIImage?
    @State private var tweaks: [URL] = []
    @State private var entitlements: URL?
    @State private var removePlugins = false
    @State private var removeWatch = true
    @State private var removeSchemes = false
    @State private var fileSharing = false
    @State private var certID: UUID?
    @State private var progress: Double = 0
    @State private var stage = ""
    @State private var signing = false
    @State private var picking: PickKind?
    @State private var done: SignedApp?
    @State private var error: String?
    @State private var setup = false

    enum PickKind: Identifiable {
        case icon, tweak, entitlements
        var id: Int { hashValue }
    }

    var cert: StoredCertificate? {
        if let id = certID { return state.certificates.first { $0.id == id } }
        return state.selectedCertificate
    }

    var forcedBundle: String? {
        guard let c = cert, !c.profile.isWildcard else { return nil }
        return c.profile.bundleID
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Button { picking = .icon } label: {
                            ZStack(alignment: .bottomTrailing) {
                                AppIconView(image: iconImage ?? state.icon(for: app), size: 66)
                                Image(systemName: "pencil.circle.fill").font(.title3).foregroundColor(Theme.rose).background(Circle().fill(Color.white))
                            }
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name).font(.title3.weight(.bold))
                            Text("\(app.bundleID) · v\(app.version)").font(.caption).foregroundColor(.secondary)
                            if app.encrypted {
                                Text(L("This IPA is encrypted and will not run. Use a decrypted IPA.")).font(.caption).foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text(L("Certificate"))) {
                    if state.certificates.isEmpty {
                        Button(L("Add a certificate first")) { dismiss(); state.tab = 1 }
                    } else {
                        Picker(L("Certificate"), selection: Binding(get: { cert?.id }, set: { certID = $0 })) {
                            ForEach(state.certificates) { c in
                                Text(c.nickname).tag(Optional(c.id))
                            }
                        }
                        if let c = cert {
                            HStack {
                                StatusDot(status: c.ocsp, expired: c.isExpired)
                                Spacer()
                                Text(c.profile.isWildcard ? L("Wildcard profile") : c.profile.bundleID).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text(L("App")), footer: forcedBundle.map { Text(LF("This profile only allows %@, the bundle ID will be replaced and app extensions removed.", $0)) }) {
                    LabeledField(title: L("Name"), text: $name, placeholder: app.name)
                    LabeledField(title: L("Bundle ID"), text: $bundleID, placeholder: forcedBundle ?? app.bundleID)
                        .disabled(forcedBundle != nil)
                    LabeledField(title: L("Version"), text: $version, placeholder: app.version)
                    LabeledField(title: L("Minimum iOS"), text: $minIOS, placeholder: app.minOS)
                }

                Section(header: Text(L("Tweaks")), footer: Text(L("Supports .dylib, .deb and .framework. Substrate, ElleKit and libhooker tweaks are wired to SayoHook automatically."))) {
                    ForEach(tweaks, id: \.self) { t in
                        HStack {
                            Image(systemName: t.pathExtension == "deb" ? "shippingbox.fill" : "puzzlepiece.extension.fill").foregroundColor(Theme.rose)
                            Text(t.lastPathComponent).lineLimit(1)
                        }
                    }
                    .onDelete { tweaks.remove(atOffsets: $0) }
                    let saved = savedTweaks()
                    if !saved.isEmpty {
                        Menu {
                            ForEach(saved, id: \.self) { u in
                                Button(u.lastPathComponent) { if !tweaks.contains(u) { tweaks.append(u) } }
                            }
                        } label: { Label(L("Add saved tweak"), systemImage: "tray.full") }
                    }
                    Button { picking = .tweak } label: { Label(L("Add tweak from Files"), systemImage: "plus") }
                }

                Section(header: Text(L("Options"))) {
                    Toggle(L("Remove app extensions"), isOn: $removePlugins)
                    Toggle(L("Remove Apple Watch app"), isOn: $removeWatch)
                    Toggle(L("Remove URL schemes"), isOn: $removeSchemes)
                    Toggle(L("Enable file sharing"), isOn: $fileSharing)
                    Button { picking = .entitlements } label: {
                        HStack {
                            Text(L("Extra entitlements"))
                            Spacer()
                            Text(entitlements?.lastPathComponent ?? L("None")).foregroundColor(.secondary)
                        }
                    }
                }

                if signing {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress).tint(Theme.rose)
                            Text(stageName(stage)).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                if let e = error {
                    Section { Text(e).foregroundColor(.red).font(.callout) }
                }
                if let s = done {
                    Section {
                        Button {
                            Task {
                                do {
                                    try await Installer.install(s, state: state)
                                    dismiss()
                                } catch is InstallNeedsSetup {
                                    setup = true
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        } label: { Label(L("Install now"), systemImage: "arrow.down.app.fill") }
                            .buttonStyle(PrimaryButtonStyle())
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        Button { Task { await sign() } } label: {
                            HStack {
                                if signing { ProgressView().tint(.white) }
                                Text(signing ? L("Signing…") : L("Sign"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(signing || cert == nil)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(L("Sign"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } }
            }
            .fileImporter(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
                          allowedContentTypes: pickTypes, allowsMultipleSelection: picking == .tweak) { r in
                let kind = picking
                picking = nil
                guard case .success(let urls) = r else { return }
                for u in urls { take(u, kind: kind) }
            }
            .sheet(isPresented: $setup) { InstallSetupView().environmentObject(state) }
            .onAppear {
                removePlugins = state.settings.autoRemovePlugins
                removeWatch = state.settings.removeWatchApps
            }
        }
        .interactiveDismissDisabled(signing)
    }

    var pickTypes: [UTType] {
        switch picking {
        case .icon: return [.png, .jpeg, .image]
        case .tweak: return [.deb, .dylib, .folder, .data]
        case .entitlements: return [.xml, .propertyList, .data]
        case .none: return [.data]
        }
    }

    func savedTweaks() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: Paths.tweaks, includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func take(_ u: URL, kind: PickKind?) {
        let scoped = u.startAccessingSecurityScopedResource()
        defer { if scoped { u.stopAccessingSecurityScopedResource() } }
        switch kind {
        case .icon:
            if let img = UIImage(contentsOfFile: u.path) ?? (try? Data(contentsOf: u)).flatMap(UIImage.init(data:)) {
                let size = CGSize(width: 180, height: 180)
                let r = UIGraphicsImageRenderer(size: size)
                let out = r.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
                let dst = Paths.work.appendingPathComponent("icon-\(UUID().uuidString).png")
                try? out.pngData()?.write(to: dst)
                iconURL = dst
                iconImage = out
            }
        case .tweak:
            let dst = Paths.tweaks.appendingPathComponent(u.lastPathComponent)
            try? FileManager.default.removeItem(at: dst)
            do {
                try FileManager.default.copyItem(at: u, to: dst)
                if !tweaks.contains(dst) { tweaks.append(dst) }
            } catch {
                self.error = error.localizedDescription
            }
        case .entitlements:
            let dst = Paths.work.appendingPathComponent(u.lastPathComponent)
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: u, to: dst)
            entitlements = dst
        case .none:
            break
        }
    }

    func stageName(_ s: String) -> String {
        switch s {
        case "copy": return L("Preparing")
        case "prepare": return L("Patching Info.plist")
        case "inject": return L("Injecting tweaks")
        case "sign": return L("Signing binaries")
        case "zip": return L("Packing IPA")
        default: return s
        }
    }

    func sign() async {
        guard let c = cert else { error = L("Choose a certificate"); return }
        error = nil
        signing = true
        progress = 0
        stage = "copy"
        defer { signing = false }
        let src = state.appURL(app)
        let workRoot = Paths.work.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let payload = workRoot.appendingPathComponent("Payload", isDirectory: true)
        let appCopy = payload.appendingPathComponent(app.appFolder)
        var opts = SayoCore.SignOptions()
        opts.bundleID = bundleID.trimmingCharacters(in: .whitespaces)
        opts.displayName = name.trimmingCharacters(in: .whitespaces)
        opts.shortVersion = version.trimmingCharacters(in: .whitespaces)
        opts.minIOS = minIOS.trimmingCharacters(in: .whitespaces)
        opts.iconPNG = iconURL
        opts.entitlements = entitlements
        opts.removePlugins = removePlugins
        opts.removeWatch = removeWatch
        opts.removeURLSchemes = removeSchemes
        opts.fileSharing = fileSharing
        opts.compression = Int32(state.settings.compressionLevel)
        let tweakList = tweaks
        let compression = Int32(state.settings.compressionLevel)
        let appCopyName = app.appFolder
        let appName = name.isEmpty ? app.name : name
        let certName = c.nickname
        let libID = app.id
        do {
            let identity = try state.identity(for: c)
            var profile: Data
            if c.fromAppleID {
                stage = L("Requesting profile from Apple")
                let wanted = opts.bundleID.isEmpty ? app.bundleID : opts.bundleID
                let (p, finalID) = try await AppleAccount.profile(for: c, bundleID: wanted, name: appName, anisetteURL: state.settings.anisetteURL)
                profile = p
                opts.bundleID = finalID
            } else {
                guard let files = state.certificateFiles(c) else { throw SayoError(L("Certificate files are missing")) }
                profile = files.profile
            }
            let finalOpts = opts
            let profileData = profile
            let result: SignedApp = try await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                try fm.createDirectory(at: payload, withIntermediateDirectories: true)
                try fm.copyItem(at: src, to: appCopy)
                var o = finalOpts
                var temp: [URL] = []
                for t in tweakList {
                    if t.pathExtension.lowercased() == "deb" {
                        let d = workRoot.appendingPathComponent("deb-\(UUID().uuidString)")
                        temp.append(d)
                        o.injections += try SayoCore.extractDeb(t, to: d)
                    } else {
                        o.injections.append(t)
                    }
                }
                if !o.injections.isEmpty, let fw = Bundle.main.privateFrameworksURL?.appendingPathComponent("CydiaSubstrate.framework"),
                   fm.fileExists(atPath: fw.path) {
                    o.hookFramework = fw
                }
                try SayoCore.signApp(app: appCopy, profile: profileData, identity: identity, options: o) { f, s in
                    Task { @MainActor in
                        self.progress = f * 0.92
                        self.stage = s
                    }
                }
                Task { @MainActor in self.stage = "zip"; self.progress = 0.93 }
                let info = NSDictionary(contentsOf: appCopy.appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
                let finalID = info["CFBundleIdentifier"] as? String ?? ""
                let finalVersion = info["CFBundleShortVersionString"] as? String ?? ""
                let finalName = (info["CFBundleDisplayName"] as? String) ?? appName
                let safe = finalName.replacingOccurrences(of: "/", with: "-")
                let fileName = "\(safe)_\(finalVersion)_\(UUID().uuidString.prefix(6)).ipa"
                let out = Paths.signed.appendingPathComponent(fileName)
                for t in temp { try? fm.removeItem(at: t) }
                try SayoCore.zip(workRoot.appendingPathComponent("Payload").deletingLastPathComponent(), to: out, level: compression)
                try? fm.removeItem(at: workRoot)
                let size = (try? fm.attributesOfItem(atPath: out.path)[.size] as? NSNumber)?.int64Value ?? 0
                _ = appCopyName
                return SignedApp(id: UUID(), libraryID: libID, name: finalName, bundleID: finalID, version: finalVersion,
                                 certificateName: certName, signedAt: Date(), ipaFile: fileName, size: size,
                                 tweaks: tweakList.map { $0.lastPathComponent })
            }.value
            progress = 1
            state.signed.insert(result, at: 0)
            state.save()
            done = result
            state.show(LF("%@ is signed", result.name))
        } catch {
            try? FileManager.default.removeItem(at: workRoot)
            self.error = error.localizedDescription
        }
    }
}

struct LabeledField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 16)
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(.secondary)
        }
    }
}
