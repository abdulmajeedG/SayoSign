import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var setup = false
    @State private var confirmReset = false
    @State private var cacheSize: Int64 = 0
    @State private var installLog: [String] = []
    @State private var pairing = false
    @State private var checking = false
    @State private var anisetteInfo: [(String, String)]?
    @State private var anisetteError: String?
    @State private var customServer = false
    @State private var language = false
    @State private var about = false

    var serverChoice: Binding<String> {
        Binding(get: {
            if customServer { return "custom" }
            return Anisette.presets.contains(where: { $0.url == state.settings.anisetteURL }) ? state.settings.anisetteURL : "custom"
        }, set: { v in
            anisetteInfo = nil
            anisetteError = nil
            if v == "custom" {
                customServer = true
            } else {
                customServer = false
                state.settings.anisetteURL = v
            }
        })
    }

    var showCustomServer: Bool {
        customServer || !Anisette.presets.contains(where: { $0.url == state.settings.anisetteURL })
    }

    var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    func checkAnisette() async {
        checking = true
        anisetteError = nil
        defer { checking = false }
        do {
            let a = try await Anisette.fetch(state.settings.anisetteURL)
            var rows: [(String, String)] = [
                (L("Protocol"), a.version),
                (L("Status"), a.isProvisioned ? L("Provisioned") : L("Not provisioned")),
                (L("Client"), a.isMacClient ? "Mac ✓" : (a.isLegacyClient ? L("Legacy (rejected by Apple)") : L("Non-Mac"))),
                ("Client info", a.clientInfo),
                ("User-Agent", a.userAgent),
                (L("Device ID"), a.deviceID),
            ]
            if !a.isMacClient { rows.append((L("Warning"), L("Apple may reject this server. Prefer a Mac-based one."))) }
            anisetteInfo = rows
            Haptics.success()
        } catch {
            anisetteInfo = nil
            anisetteError = error.localizedDescription
            Haptics.error()
        }
    }

    func compressionName(_ level: Int) -> String {
        switch level {
        case 0: return L("None (fastest)")
        case 1: return L("Fast")
        case 6: return L("Balanced")
        default: return L("Smallest")
        }
    }

    func installMethodName(_ value: Int) -> String {
        switch value {
        case 1: return L("Over the air")
        case 2: return L("Pairing (LocalDevVPN)")
        default: return L("Automatic")
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground()
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        BrandHeader(compact: true)
                        PageTitle(eyebrow: L("Personalize"),
                                  title: L("Settings"),
                                  subtitle: L("Make SayoSign feel like yours."))
                            .padding(.top, 2)
                        identityCard

                        SettingsPanel(title: L("Appearance"), subtitle: L("Choose how SayoSign looks."), symbol: "paintbrush.fill") {
                            HStack(spacing: 8) {
                                AppearanceOption(title: L("System"), symbol: "circle.lefthalf.filled",
                                                 selected: state.settings.appearance == 0,
                                                 accessibilityID: "appearance.system") {
                                    withAnimation(.easeInOut(duration: 0.2)) { state.settings.appearance = 0 }
                                }
                                AppearanceOption(title: L("Light"), symbol: "sun.max.fill",
                                                 selected: state.settings.appearance == 1,
                                                 accessibilityID: "appearance.light") {
                                    withAnimation(.easeInOut(duration: 0.2)) { state.settings.appearance = 1 }
                                }
                                AppearanceOption(title: L("Dark"), symbol: "moon.stars.fill",
                                                 selected: state.settings.appearance == 2,
                                                 accessibilityID: "appearance.dark") {
                                    withAnimation(.easeInOut(duration: 0.2)) { state.settings.appearance = 2 }
                                }
                            }
                            DividerSoft().padding(.vertical, 4)
                            SettingsLinkRow(title: L("Language"),
                                            subtitle: L("Change the app language instantly"),
                                            symbol: "character.bubble.fill",
                                            tint: Theme.lilac,
                                            value: LocalizationManager.shared.language.nativeName,
                                            accessibilityID: "settings.language") {
                                language = true
                            }
                        }

                        SettingsPanel(title: L("Install method"), symbol: "arrow.down.app.fill",
                                      footer: L("Free Apple ID apps can only be installed through pairing (like SideStore): iOS 27, Developer Mode and LocalDevVPN. Certificates (.p12) install over the air.")) {
                            Menu {
                                Button { state.settings.installMethod = 0 } label: {
                                    Label(L("Automatic"), systemImage: state.settings.installMethod == 0 ? "checkmark" : "")
                                }
                                Button { state.settings.installMethod = 1 } label: {
                                    Label(L("Over the air"), systemImage: state.settings.installMethod == 1 ? "checkmark" : "")
                                }
                                Button { state.settings.installMethod = 2 } label: {
                                    Label(L("Pairing (LocalDevVPN)"), systemImage: state.settings.installMethod == 2 ? "checkmark" : "")
                                }
                            } label: {
                                SettingsValueRow(title: L("Method"), value: installMethodName(state.settings.installMethod),
                                                 symbol: "arrow.left.arrow.right", tint: Theme.info)
                            }
                            DividerSoft()
                            SettingsLinkRow(title: L("Pair this iPhone"),
                                            subtitle: L("Install Apple ID apps through the tunnel"),
                                            symbol: "iphone.and.arrow.forward",
                                            tint: Theme.mint,
                                            value: DeviceLink.isPaired ? L("Paired") : L("Not paired"),
                                            accessibilityID: "settings.pair") {
                                pairing = true
                            }
                        }

                        SettingsPanel(title: L("Installing"), symbol: "shippingbox.fill",
                                      footer: L("With a manifest service, iOS just asks to install the app; nothing to set up. Leave it empty to use the local HTTPS installer and its one-time profile.")) {
                            SayoTextField(title: L("Manifest service (https://…workers.dev)"),
                                          placeholder: "https://…workers.dev",
                                          text: $state.settings.manifestService,
                                          keyboard: .URL,
                                          capitalization: .never)
                            if state.settings.manifestService.trimmingCharacters(in: .whitespaces).isEmpty {
                                SettingsLinkRow(title: L("Local installer setup"),
                                                subtitle: L("One-time trust profile"),
                                                symbol: "lock.shield",
                                                tint: Theme.gold,
                                                accessibilityID: "settings.localInstaller") { setup = true }
                            }
                            DividerSoft()
                            ToggleRow(title: L("Stay alive while installing"),
                                      subtitle: L("Keeps the install server running in the background"),
                                      symbol: "waveform.path.ecg",
                                      isOn: $state.settings.keepAliveAudio)
                            DividerSoft()
                            HStack {
                                IconBadge(symbol: "number", tint: Theme.info, size: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L("Server port"))
                                        .font(SayoType.bodyStrong)
                                        .foregroundColor(Theme.textPrimary)
                                    Text("\(state.settings.serverPort)")
                                        .font(SayoType.mono)
                                        .foregroundColor(Theme.textTertiary)
                                }
                                Spacer()
                                Stepper("", value: $state.settings.serverPort, in: 1025...65000, step: 2)
                                    .labelsHidden()
                                    .tint(Theme.coral)
                            }
                            .padding(.vertical, 9)
                        }

                        SettingsPanel(title: L("Signing"), symbol: "signature") {
                            Menu {
                                ForEach([0, 1, 6, 9], id: \.self) { level in
                                    Button { state.settings.compressionLevel = level } label: {
                                        Label(compressionName(level), systemImage: state.settings.compressionLevel == level ? "checkmark" : "")
                                    }
                                }
                            } label: {
                                SettingsValueRow(title: L("Compression"),
                                                 value: compressionName(state.settings.compressionLevel),
                                                 symbol: "archivebox.fill", tint: Theme.lilac)
                            }
                            DividerSoft()
                            ToggleRow(title: L("Remove app extensions by default"),
                                      symbol: "puzzlepiece.extension.fill",
                                      isOn: $state.settings.autoRemovePlugins)
                            DividerSoft()
                            ToggleRow(title: L("Remove Watch apps by default"),
                                      symbol: "applewatch",
                                      isOn: $state.settings.removeWatchApps)
                        }

                        SettingsPanel(title: L("Anisette server"), symbol: "server.rack",
                                      footer: L("Apple only accepts Mac-based anisette servers since October 2026. Use one of these, your own server, or the one SayoSign Desktop runs on your computer (scan its QR code).")) {
                            Menu {
                                ForEach(Anisette.presets, id: \.url) { p in
                                    Button {
                                        serverChoice.wrappedValue = p.url
                                    } label: {
                                        Label(p.name, systemImage: state.settings.anisetteURL == p.url ? "checkmark" : "")
                                    }
                                }
                                Button { serverChoice.wrappedValue = "custom" } label: {
                                    Label(L("Custom"), systemImage: showCustomServer ? "checkmark" : "")
                                }
                            } label: {
                                SettingsValueRow(title: L("Server"),
                                                 value: serverName,
                                                 symbol: "network", tint: Theme.info)
                            }
                            if showCustomServer {
                                SayoTextField(title: L("Server"), placeholder: "https://…",
                                              text: $state.settings.anisetteURL,
                                              keyboard: .URL, capitalization: .never, mono: true)
                                    .padding(.top, 2)
                            }
                            DividerSoft()
                            Button {
                                Task { await checkAnisette() }
                            } label: {
                                HStack(spacing: 10) {
                                    IconBadge(symbol: "bolt.horizontal.circle.fill", tint: Theme.gold, size: 32)
                                    Text(L("Check server"))
                                        .font(SayoType.bodyStrong)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    if checking { ProgressView().scaleEffect(0.8) }
                                    else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                }
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(checking)
                            if let info = anisetteInfo {
                                VStack(spacing: 7) {
                                    ForEach(info.indices, id: \.self) { i in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text(info[i].0)
                                                .font(SayoType.micro)
                                                .foregroundColor(Theme.textTertiary)
                                            Spacer(minLength: 8)
                                            Text(info[i].1)
                                                .font(SayoType.monoSmall)
                                                .foregroundColor(Theme.textSecondary)
                                                .multilineTextAlignment(.trailing)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                                .padding(11)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous).fill(Theme.surfaceInset.opacity(0.6)))
                            }
                            if let e = anisetteError {
                                BannerView(kind: .error, text: e)
                            }
                            Button(role: .destructive) {
                                Haptics.warning()
                                Anisette(server: state.settings.anisetteURL).reset()
                                anisetteInfo = nil
                                state.show(L("Anisette was reset"))
                            } label: {
                                Label(L("Reset anisette"), systemImage: "arrow.counterclockwise")
                                    .font(SayoType.captionStrong)
                                    .foregroundColor(Theme.danger)
                            }
                            .padding(.top, 3)
                        }

                        SettingsPanel(title: L("Apple ID"), symbol: "applelogo") {
                            SayoTextField(title: "UDID", placeholder: "00008110-…",
                                          text: $state.settings.udid,
                                          capitalization: .characters, mono: true)
                            Text(L("Your iPhone UDID is needed to register it with Apple. Find it in Finder/iTunes or on a UDID website."))
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SettingsPanel(title: L("Storage"), symbol: "internaldrive.fill") {
                            SettingsValueRow(title: L("Temporary files"), value: formatSize(cacheSize),
                                             symbol: "externaldrive.fill", tint: Theme.textSecondary)
                            DividerSoft()
                            Button {
                                Haptics.light()
                                try? FileManager.default.removeItem(at: Paths.work)
                                cacheSize = AppState.folderSize(Paths.work)
                                state.show(L("Cleared"))
                            } label: {
                                Label(L("Clear temporary files"), systemImage: "trash")
                                    .font(SayoType.captionStrong)
                                    .foregroundColor(Theme.coral)
                            }
                            .padding(.vertical, 9)
                            DividerSoft()
                            Button(role: .destructive) {
                                confirmReset = true
                            } label: {
                                Label(L("Reset local installer"), systemImage: "arrow.counterclockwise")
                                    .font(SayoType.captionStrong)
                                    .foregroundColor(Theme.danger)
                            }
                            .padding(.vertical, 9)
                        }

                        SettingsPanel(title: L("Install log"), symbol: "doc.text.magnifyingglass",
                                      footer: L("What iOS requested during the last install. Send a screenshot if an install fails.")) {
                            if installLog.isEmpty {
                                Text(L("No install yet"))
                                    .font(SayoType.caption)
                                    .foregroundColor(Theme.textTertiary)
                                    .padding(.vertical, 5)
                            } else {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(installLog.indices, id: \.self) { i in
                                            Text(installLog[i])
                                                .font(SayoType.monoSmall)
                                                .foregroundColor(Theme.textSecondary)
                                                .textSelection(.enabled)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .frame(maxHeight: 180)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous).fill(Theme.surfaceInset.opacity(0.6)))
                            }
                            Button {
                                installLog = InstallServer.shared.logLines()
                            } label: {
                                Label(L("Refresh"), systemImage: "arrow.clockwise")
                                    .font(SayoType.captionStrong)
                                    .foregroundColor(Theme.coral)
                            }
                            .padding(.top, 4)
                        }

                        SettingsPanel(title: L("About"), symbol: "info.circle.fill") {
                            SettingsLinkRow(title: L("About & credits"),
                                            subtitle: "SayoSign " + version,
                                            symbol: "heart.text.square.fill",
                                            tint: Theme.coral,
                                            accessibilityID: "settings.about") { about = true }
                            DividerSoft()
                            Link(destination: URL(string: "https://github.com/murk-sus/SayoSign")!) {
                                linkRow(title: "GitHub", symbol: "chevron.left.forwardslash.chevron.right")
                            }
                            DividerSoft()
                            Link(destination: URL(string: "https://murk-sus.github.io/SayoSign/")!) {
                                linkRow(title: L("Website"), symbol: "safari")
                            }
                            DividerSoft()
                            designerStrip
                        }

                        PageFooter(version: version)
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $setup) { InstallSetupView().environmentObject(state) }
            .sheet(isPresented: $pairing) { PairingView().environmentObject(state) }
            .sheet(isPresented: $language) { LanguagePickerView().environmentObject(state) }
            .sheet(isPresented: $about) { AboutView().environmentObject(state) }
            .confirmationDialog(L("Reset local installer?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L("Reset"), role: .destructive) {
                    InstallServer.shared.stop()
                    LocalCA.reset()
                    state.show(L("Local installer reset. Remove the old profile in Settings."))
                    Haptics.warning()
                }
            }
            .onAppear {
                cacheSize = AppState.folderSize(Paths.work)
                installLog = InstallServer.shared.logLines()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var serverName: String {
        Anisette.presets.first { $0.url == state.settings.anisetteURL }?.name ?? L("Custom")
    }

    private var identityCard: some View {
        Button {
            Haptics.light()
            about = true
        } label: {
            HStack(spacing: 14) {
                BrandMark(size: 62)
                    .shadow(color: Theme.rose.opacity(0.22), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SayoSign")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.gradient)
                    Text(L("On-device IPA signer"))
                        .font(SayoType.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    HStack(spacing: 5) {
                        Text("v" + version)
                        Text("·")
                        Text(L("Designed with care"))
                    }
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textTertiary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                    .shadow(color: Theme.rose.opacity(0.05), radius: 18, y: 8)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func linkRow(title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: Theme.textSecondary, size: 32)
            Text(title)
                .font(SayoType.bodyStrong)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var designerStrip: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Theme.rose.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.rose)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(L("Designed with love by"))
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
                Link("@abdulmajeedG", destination: URL(string: "https://t.me/abdulmajeedG")!)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(Theme.coral)
            }
            Spacer()
            Image(systemName: "paperplane.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.coral.opacity(0.7))
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Settings building blocks

struct SettingsPanel<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String
    var footer: String? = nil
    let content: Content

    init(title: String, subtitle: String? = nil, symbol: String, footer: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel(title: title, subtitle: subtitle, symbol: symbol)
            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                    .shadow(color: Color.black.opacity(0.03), radius: 14, y: 6)
            )
            if let footer = footer {
                Text(footer)
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = Theme.coral
    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: tint, size: 32)
            Text(title)
                .font(SayoType.bodyStrong)
                .foregroundColor(Theme.textPrimary)
            Spacer(minLength: 8)
            Text(value)
                .font(SayoType.captionStrong)
                .foregroundColor(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textTertiary.opacity(0.7))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct PageFooter: View {
    let version: String
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.coral.opacity(0.7))
                Text("SayoSign " + version)
                Text("·")
                Text("GPL-3.0")
            }
            .font(SayoType.micro)
            .foregroundColor(Theme.textTertiary)
            Text(L("Made with 🎀 by murk. Licensed under GPL-3.0. Icon uses Twemoji (CC-BY 4.0)."))
                .font(.system(size: 9.5))
                .foregroundColor(Theme.textTertiary.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }
}

// MARK: - Language picker

struct LanguagePickerView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground(accent: Theme.lilac)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            IconBadge(symbol: "character.bubble.fill", tint: Theme.lilac, size: 50)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("Choose your language"))
                                    .font(SayoType.title)
                                    .foregroundColor(Theme.textPrimary)
                                Text(L("Changes apply immediately."))
                                    .font(SayoType.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, language in
                                LanguageRow(language: language, selected: localization.language == language,
                                       accessibilityID: "language.\(language.rawValue)") {
                                    localization.set(language)
                                    dismiss()
                                }
                                if index < AppLanguage.allCases.count - 1 {
                                    DividerSoft()
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                        )
                        Text(L("Technical identifiers, file extensions and protocol names stay unchanged."))
                            .font(SayoType.micro)
                            .foregroundColor(Theme.textTertiary)
                            .padding(.horizontal, 4)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Close")) { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - About and credits

struct AboutView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            BrandMark(size: 88)
                                .shadow(color: Theme.rose.opacity(0.3), radius: 24, y: 12)
                            VStack(spacing: 3) {
                                Text("SayoSign")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.gradient)
                                Text(L("On-device IPA signer"))
                                    .font(SayoType.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Text("v" + version)
                                    .font(SayoType.micro)
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .padding(.top, 14)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: L("About"))
                            Text(L("Made with 🎀 by murk. Licensed under GPL-3.0. Icon uses Twemoji (CC-BY 4.0)."))
                                .font(SayoType.body)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                            DividerSoft()
                            Link(destination: URL(string: "https://github.com/murk-sus/SayoSign")!) {
                                aboutLink(title: "GitHub", subtitle: L("Original project"), symbol: "chevron.left.forwardslash.chevron.right")
                            }
                            Link(destination: URL(string: "https://murk-sus.github.io/SayoSign/")!) {
                                aboutLink(title: L("Website"), subtitle: "murk-sus.github.io/SayoSign", symbol: "safari")
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                        )

                        designerCard

                        VStack(spacing: 4) {
                            Text(L("Sign. Install. Create."))
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundColor(Theme.textTertiary)
                            Text("SayoSign " + version)
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary.opacity(0.8))
                        }
                        .padding(.top, 6)
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Close")) { dismiss() }
                        .accessibilityIdentifier("about.close")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var designerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.rose)
                Text(L("Design & experience").uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundColor(Theme.rose)
                Spacer()
            }
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.inkGradient)
                        .frame(width: 52, height: 52)
                    Text("A")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.coral))
                        .overlay(Circle().stroke(Theme.surface, lineWidth: 1.4))
                        .offset(x: 18, y: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Designed with love by"))
                        .font(SayoType.caption)
                        .foregroundColor(Theme.textSecondary)
                    Link("@abdulmajeedG", destination: URL(string: "https://t.me/abdulmajeedG")!)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(L("Telegram Designer"))
                        .font(SayoType.micro)
                        .foregroundColor(Theme.coral)
                }
                Spacer()
            }
            Link(destination: URL(string: "https://t.me/abdulmajeedG")!) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("t.me/abdulmajeedG")
                        .font(SayoType.captionStrong)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.inkGradient)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [Theme.coral.opacity(0.45), Theme.lilac.opacity(0.25), Theme.border.opacity(0.4)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: Theme.coral.opacity(0.07), radius: 20, y: 10)
        )
    }

    private func aboutLink(title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: Theme.textSecondary, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(SayoType.bodyStrong)
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

// MARK: - Local installer setup

struct InstallSetupView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var phase
    @State private var trusted = false
    @State private var checking = false
    @State private var error: String?
    @State private var share: URL?

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground(accent: Theme.gold)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(trusted ? Theme.success.opacity(0.12) : Theme.gold.opacity(0.11))
                                    .frame(width: 104, height: 104)
                                Circle()
                                    .stroke(trusted ? Theme.success.opacity(0.2) : Theme.gold.opacity(0.18), lineWidth: 1)
                                    .frame(width: 82, height: 82)
                                Image(systemName: trusted ? "checkmark.shield.fill" : "lock.shield.fill")
                                    .font(.system(size: 42, weight: .medium))
                                    .foregroundColor(trusted ? Theme.success : Theme.gold)
                            }
                            VStack(spacing: 4) {
                                Text(trusted ? L("All set!") : L("One-time setup"))
                                    .font(SayoType.title)
                                    .foregroundColor(Theme.textPrimary)
                                Text(L("Local installer"))
                                    .font(SayoType.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                        Text(L("iOS only installs apps over HTTPS. SayoSign made a private certificate authority on this iPhone, its key never leaves the device. Trust it once and installs work offline forever."))
                            .font(SayoType.callout)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .fill(Theme.surface)
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                            )

                        VStack(alignment: .leading, spacing: 0) {
                            setupStep(1, L("Download the profile"), L("Tap the button and allow the download in Safari.")) {
                                Button { Task { await openProfile() } } label: {
                                    Label(L("Download profile"), systemImage: "arrow.down.doc.fill")
                                }
                                .buttonStyle(SmallButtonStyle())
                            }
                            stepConnect
                            setupStep(2, L("Install it"), L("Settings → General → VPN & Device Management → SayoSign Local Installer → Install.")) {
                                Button {
                                    Haptics.light()
                                    if let u = URL(string: "App-prefs:General&path=ManagedConfigurationList") ?? URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(u)
                                    }
                                } label: {
                                    Label(L("Open Settings"), systemImage: "gear")
                                }
                                .buttonStyle(SmallButtonStyle(filled: false))
                            }
                            stepConnect
                            setupStep(3, L("Enable full trust"), L("Settings → General → About → Certificate Trust Settings → turn on SayoSign Local CA.")) {
                                EmptyView()
                            }
                        }

                        if let e = error {
                            BannerView(kind: .error, text: e)
                        }

                        Button {
                            Haptics.medium()
                            if trusted { dismiss() } else { Task { await check() } }
                        } label: {
                            HStack(spacing: 8) {
                                if checking { ProgressView().tint(.white).scaleEffect(0.8) }
                                Text(trusted ? L("Done") : L("Check again"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(L("Save profile to Files instead")) {
                            if let d = LocalCA.mobileconfig() {
                                let u = Paths.work.appendingPathComponent("SayoSign.mobileconfig")
                                try? d.write(to: u)
                                share = u
                            }
                        }
                        .font(SayoType.captionStrong)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Close")) { dismiss() }
                        .accessibilityIdentifier("setup.close")
                }
            }
            .sheet(item: Binding(get: { share.map { ShareItem(url: $0) } }, set: { share = $0?.url })) { ShareSheet(items: [$0.url]) }
            .task { await check() }
            .onChange(of: phase) { p in if p == .active { Task { await check() } } }
        }
        .navigationViewStyle(.stack)
    }

    private var stepConnect: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1.5, height: 20)
            .padding(.leading, 15)
    }

    private func setupStep<V: View>(_ n: Int, _ title: String, _ text: String, @ViewBuilder action: () -> V) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text("\(n)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .frame(width: 31, height: 31)
                .background(Circle().fill(Theme.inkGradient))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SayoType.headline)
                    .foregroundColor(Theme.textPrimary)
                Text(text)
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                action()
            }
            .padding(.bottom, 12)
        }
    }

    func openProfile() async {
        do {
            try InstallServer.shared.start(port: state.settings.serverPort)
            InstallServer.shared.keepAlive(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { InstallServer.shared.keepAlive(false) }
            if let u = URL(string: "\(InstallServer.shared.httpBase)/ca.mobileconfig") {
                await UIApplication.shared.open(u)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func check() async {
        checking = true
        defer { checking = false }
        do {
            try InstallServer.shared.start(port: state.settings.serverPort)
            trusted = await Installer.trusted(port: state.settings.serverPort)
            error = nil
            if trusted { Haptics.success() }
        } catch {
            self.error = error.localizedDescription
        }
        if trusted { InstallServer.shared.keepAlive(false) }
    }
}
