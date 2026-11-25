import SwiftUI
import UniformTypeIdentifiers

struct SignView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    let app: LibraryApp

    @State private var name = ""
    @State private var bundleID = ""
    @State private var keepOwnID = true
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
    @State private var inside = false
    @State private var certID: UUID?
    @State private var progress: Double = 0
    @State private var stage = ""
    @State private var signing = false
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

    var explicitBundle: String? {
        guard let c = cert, !c.fromAppleID, !c.profile.isWildcard else { return nil }
        return c.profile.bundleID
    }

    var forcedBundle: String? { keepOwnID ? nil : explicitBundle }

    var stageIndex: Int {
        switch stage {
        case "copy": return 0
        case "prepare": return 1
        case "inject": return 2
        case "sign": return 3
        case "zip": return 4
        default: return 0
        }
    }

    let steps = ["copy", "prepare", "inject", "sign", "zip"]

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topBar
                        appSummary

                        if let s = done {
                            successView(s)
                        } else {
                            certificateSection
                            detailsSection
                            tweaksSection
                            optionsSection
                            if signing { progressSection }
                            if let e = error {
                                BannerView(kind: .error, text: e)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: done?.id)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $setup) { InstallSetupView().environmentObject(state) }
            .onAppear {
                removePlugins = state.settings.autoRemovePlugins
                removeWatch = state.settings.removeWatchApps
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(signing)
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 0.7)))
            }
            .disabled(signing)
            .accessibilityLabel(L("Close"))
            VStack(alignment: .leading, spacing: 1) {
                Text(L("Sign"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(Theme.textPrimary)
                Text(signing ? L("Signing…") : (done == nil ? L("Review and sign") : L("Done")))
                    .font(SayoType.micro)
                    .foregroundColor(signing ? Theme.coral : Theme.textTertiary)
            }
            Spacer()
            if signing {
                ProgressRing(progress: progress, lineWidth: 4, size: 38)
            } else {
                BrandMark(size: 34)
            }
        }
    }

    private var appSummary: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 14) {
                Button { pick(.icon) } label: {
                    ZStack(alignment: .bottomTrailing) {
                        AppIconView(image: iconImage ?? state.icon(for: app), size: 68)
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.inkGradient))
                            .overlay(Circle().stroke(Theme.surface, lineWidth: 1.6))
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Change icon"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                    Text(app.bundleID)
                        .font(SayoType.micro)
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Pill(text: "v" + app.version)
                        Pill(text: formatSize(app.size), color: Theme.textSecondary)
                        if app.encrypted { Pill(text: L("Encrypted"), color: Theme.danger) }
                    }
                }
                Spacer(minLength: 0)
            }
            if app.encrypted {
                DividerSoft()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.danger)
                    Text(L("This IPA is encrypted and will not run. Use a decrypted IPA."))
                        .font(SayoType.caption)
                        .foregroundColor(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                .shadow(color: Color.black.opacity(0.035), radius: 14, y: 6)
        )
    }

    // MARK: - Certificate

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Certificate"))
            if state.certificates.isEmpty {
                Button {
                    Haptics.light()
                    dismiss()
                    state.tab = 1
                } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "key.fill", tint: Theme.coral, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Add a certificate first"))
                                .font(SayoType.bodyStrong)
                                .foregroundColor(Theme.textPrimary)
                            Text(L("Import a .p12 or sign in with Apple ID"))
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.coral)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.coral.opacity(0.22), lineWidth: 0.8))
                    )
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(spacing: 10) {
                    Menu {
                        ForEach(state.certificates) { c in
                            Button {
                                certID = c.id
                                Haptics.selection()
                            } label: {
                                Label(c.nickname, systemImage: c.id == cert?.id ? "checkmark" : "circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.inkGradient)
                                    .frame(width: 42, height: 42)
                                Image(systemName: cert?.fromAppleID == true ? "applelogo" : "seal.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cert?.nickname ?? L("Choose a certificate"))
                                    .font(SayoType.bodyStrong)
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(cert?.profile.teamName ?? "")
                                    .font(SayoType.micro)
                                    .foregroundColor(Theme.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if state.certificates.count > 1 {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .padding(13)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                        )
                    }
                    if let c = cert {
                        HStack(spacing: 8) {
                            StatusDot(status: c.ocsp, expired: c.isExpired)
                            Pill(text: LF("%d days left", c.daysLeft), color: c.daysLeft < 14 ? Theme.warning : Theme.success)
                            Spacer()
                            Text(c.profile.isWildcard ? L("Wildcard profile") : c.profile.bundleID)
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 3)
                    }
                }
            }
        }
    }

    // MARK: - App details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("App"), subtitle: explicitBundle.map { fb in
                keepOwnID
                    ? LF("This profile is made for %@. The app keeps its own bundle ID, so several apps can be installed side by side; app extensions are removed.", fb)
                    : LF("This profile only allows %@, the bundle ID will be replaced and app extensions removed.", fb)
                        + (fb.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") == .orderedSame
                           ? "\n\n⚠️ " + L("SayoSign itself has this bundle ID. An app signed with this certificate cannot be installed while SayoSign uses the same ID.")
                           : "")
            })
            VStack(spacing: 0) {
                if explicitBundle != nil {
                    ToggleRow(title: L("Keep the app's own bundle ID"),
                              subtitle: L("Keeps extensions and side-by-side installs"),
                              symbol: "number.square.fill",
                              isOn: $keepOwnID)
                    DividerSoft()
                }
                SayoLabeledField(title: L("Name"), text: $name, placeholder: app.name)
                DividerSoft()
                SayoLabeledField(title: L("Bundle ID"), text: $bundleID, placeholder: forcedBundle ?? app.bundleID, mono: true)
                    .disabled(forcedBundle != nil)
                    .opacity(forcedBundle != nil ? 0.55 : 1)
                DividerSoft()
                SayoLabeledField(title: L("Version"), text: $version, placeholder: app.version)
                DividerSoft()
                SayoLabeledField(title: L("Minimum iOS"), text: $minIOS, placeholder: app.minOS)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
            )
        }
    }

    // MARK: - Tweaks

    private var tweaksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Tweaks"),
                         subtitle: L("Supports .dylib, .deb and .framework. Substrate, ElleKit and libhooker tweaks are wired to SayoHook automatically."))
            VStack(spacing: 0) {
                ForEach(tweaks, id: \.self) { t in
                    HStack(spacing: 11) {
                        IconBadge(symbol: t.pathExtension == "deb" ? "shippingbox.fill" : "puzzlepiece.extension.fill",
                                  tint: Theme.lilac, size: 32)
                        Text(t.lastPathComponent)
                            .font(SayoType.captionStrong)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            Haptics.light()
                            tweaks.removeAll { $0 == t }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("Remove"))
                    }
                    .padding(.vertical, 8)
                    DividerSoft()
                }
                let saved = savedTweaks()
                if !saved.isEmpty {
                    Menu {
                        ForEach(saved, id: \.self) { u in
                            Button(u.lastPathComponent) { if !tweaks.contains(u) { tweaks.append(u) } }
                        }
                    } label: {
                        HStack(spacing: 11) {
                            IconBadge(symbol: "tray.full.fill", tint: Theme.coral, size: 32)
                            Text(L("Add saved tweak"))
                                .font(SayoType.bodyStrong)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.vertical, 9)
                    }
                    DividerSoft()
                }
                Button { pick(.tweak) } label: {
                    HStack(spacing: 11) {
                        IconBadge(symbol: "plus", tint: Theme.coral, size: 32)
                        Text(L("Add tweak from Files"))
                            .font(SayoType.bodyStrong)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.coral)
                    }
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
            )
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Options"))
            VStack(spacing: 0) {
                ToggleRow(title: L("Remove app extensions"), symbol: "puzzlepiece.extension.fill", isOn: $removePlugins)
                DividerSoft()
                ToggleRow(title: L("Remove Apple Watch app"), symbol: "applewatch", isOn: $removeWatch)
                DividerSoft()
                ToggleRow(title: L("Remove URL schemes"), symbol: "link", isOn: $removeSchemes)
                DividerSoft()
                ToggleRow(title: L("Enable file sharing"), symbol: "folder.fill", isOn: $fileSharing)
                DividerSoft()
                ToggleRow(title: L("Run inside SayoSign (experimental)"),
                          subtitle: L("Like LiveContainer: not installed in iOS, no app limit. Use the same certificate SayoSign itself is signed with."),
                          symbol: "play.square.stack.fill",
                          isOn: $inside)
                DividerSoft()
                Button { pick(.entitlements) } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "list.bullet.rectangle.portrait.fill", tint: Theme.gold, size: 32)
                        Text(L("Extra entitlements"))
                            .font(SayoType.bodyStrong)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(entitlements?.lastPathComponent ?? L("None"))
                            .font(SayoType.micro)
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
            )
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ProgressRing(progress: progress, lineWidth: 6, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Signing…"))
                        .font(SayoType.title3)
                        .foregroundColor(Theme.textPrimary)
                    Text("\(Int(progress * 100))% · \(stageName(stage))")
                        .font(SayoType.micro)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            StepRail(steps: steps.map { stageName($0) }, current: stageIndex)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.coral.opacity(0.22), lineWidth: 0.8))
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Success

    @ViewBuilder
    private func successView(_ s: SignedApp) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                SuccessSeal(size: 86)
                VStack(spacing: 4) {
                    Text(L("Signing complete"))
                        .font(SayoType.title)
                        .foregroundColor(Theme.textPrimary)
                    Text(LF("%@ is signed", s.name))
                        .font(SayoType.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                SayoInfoRow(L("Version"), s.version)
                DividerSoft()
                SayoInfoRow(L("Certificate"), s.certificateName)
                DividerSoft()
                SayoInfoRow(L("Size"), formatSize(s.size))
                if !s.tweaks.isEmpty {
                    DividerSoft()
                    SayoInfoRow(L("Tweaks"), s.tweaks.joined(separator: ", "))
                }
                if s.container == true {
                    DividerSoft()
                    SayoInfoRow(L("Inside SayoSign"), L("Yes"))
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
            )

            if s.container == true {
                Text(L("SayoSign closes; open it again and the app starts inside it. Close that app and open SayoSign again to come back."))
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            DividerSoft()
            Group {
                if let s = done {
                    if s.container == true {
                        Button {
                            Haptics.medium()
                            do {
                                try Container.run(s, ipa: state.ipaURL(s))
                            } catch let caught {
                                self.error = caught.localizedDescription
                                Haptics.error()
                            }
                        } label: {
                            Label(L("Run inside SayoSign"), systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button {
                            Task { await install(s) }
                        } label: {
                            Label(L("Install now"), systemImage: "arrow.down.app.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                } else {
                    Button {
                        Haptics.medium()
                        Task { await sign() }
                    } label: {
                        HStack(spacing: 8) {
                            if signing {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "signature")
                            }
                            Text(signing ? L("Signing…") : L("Sign"))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(signing || cert == nil)
                    .opacity(signing || cert == nil ? 0.55 : 1)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    func pick(_ kind: PickKind) {
        let types: [UTType]
        switch kind {
        case .icon: types = [.png, .jpeg, .image]
        case .tweak: types = [.deb, .dylib, .folder, .data]
        case .entitlements: types = [.xml, .propertyList, .data]
        }
        FilePicker.shared.pick(types, multiple: kind == .tweak) { urls in
            for u in urls { take(u, kind: kind) }
        }
    }

    func savedTweaks() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: Paths.tweaks, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
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
                Haptics.success()
            } catch {
                self.error = error.localizedDescription
                Haptics.error()
            }
        case .entitlements:
            let dst = Paths.work.appendingPathComponent(u.lastPathComponent)
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: u, to: dst)
            entitlements = dst
            Haptics.success()
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
        var opts = SayoCore.SignOptions()
        opts.bundleID = bundleID.trimmingCharacters(in: .whitespaces)
        if opts.bundleID.isEmpty && keepOwnID && explicitBundle != nil { opts.bundleID = app.bundleID }
        opts.displayName = name.trimmingCharacters(in: .whitespaces)
        opts.shortVersion = version.trimmingCharacters(in: .whitespaces)
        opts.minIOS = minIOS.trimmingCharacters(in: .whitespaces)
        opts.iconPNG = iconURL
        opts.entitlements = entitlements
        opts.removePlugins = removePlugins
        opts.removeWatch = removeWatch
        opts.removeURLSchemes = removeSchemes
        opts.fileSharing = fileSharing
        opts.container = inside
        do {
            let result = try await state.performSign(app: app, cert: c, options: opts, tweaks: tweaks) { f, s in
                self.progress = f
                self.stage = s
            }
            progress = 1
            done = result
            state.show(LF("%@ is signed", result.name))
            Haptics.success()
        } catch let caught {
            self.error = caught.localizedDescription
            Haptics.error()
        }
    }

    func install(_ s: SignedApp) async {
        do {
            try await Installer.install(s, state: state)
            dismiss()
        } catch is InstallNeedsSetup {
            setup = true
        } catch let caught {
            self.error = caught.localizedDescription
            Haptics.error()
        }
    }
}
