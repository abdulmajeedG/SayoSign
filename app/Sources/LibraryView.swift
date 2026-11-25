import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject var state: AppState
    @State private var importing = false
    @State private var urlPrompt = false
    @State private var urlText = ""
    @State private var segment = 0
    @State private var share: URL?
    @State private var setup = false
    @State private var search = ""

    var filteredLibrary: [LibraryApp] {
        search.isEmpty ? state.library : state.library.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.bundleID.localizedCaseInsensitiveContains(search)
        }
    }

    var filteredSigned: [SignedApp] {
        search.isEmpty ? state.signed : state.signed.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.bundleID.localizedCaseInsensitiveContains(search)
        }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return L("Good morning") }
        if hour < 18 { return L("Good afternoon") }
        return L("Good evening")
    }

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground()
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        topBar
                        heroTitle
                        certificateHero
                        quickActions
                        overview
                        if !state.signed.isEmpty {
                            recentActivity
                        }
                        librarySection
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarHidden(true)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.ipa, .tipa, .zip, .data], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    Task { for u in urls { await state.importIPA(u) } }
                }
            }
            .sheet(isPresented: $urlPrompt) {
                DownloadURLSheet(urlText: $urlText) { url in
                    Task { await state.download(url, name: url.lastPathComponent) }
                }
                .environmentObject(state)
            }
            .sheet(item: Binding(get: { share.map { ShareItem(url: $0) } }, set: { share = $0?.url })) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $setup) {
                InstallSetupView().environmentObject(state)
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Header

    private var topBar: some View {
        BrandHeader(compact: true, trailing: AnyView(
            Menu {
                Button { importing = true } label: { Label(L("Import from Files"), systemImage: "folder") }
                Button { urlPrompt = true } label: { Label(L("Download from URL"), systemImage: "link") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Theme.surface)
                            .overlay(Circle().stroke(Theme.border, lineWidth: 0.7))
                    )
            }
            .accessibilityLabel(L("Add"))
        ))
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Signing studio").uppercased())
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundColor(Theme.coral)
            Text(greeting)
                .font(SayoType.hero)
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L("Everything you need to sign, in one place."))
                .font(SayoType.subheadline)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    // MARK: - Certificate hero

    @ViewBuilder
    private var certificateHero: some View {
        if let c = state.selectedCertificate {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.inkGradient)
                    // Ribbon-like decoration, subtle enough to keep text readable.
                    Bow()
                        .fill(Color.white.opacity(0.055))
                        .frame(width: 210, height: 190)
                        .rotationEffect(.degrees(-16))
                        .offset(x: 52, y: -26)
                        .allowsHitTesting(false)
                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        .frame(width: 170, height: 170)
                        .offset(x: 54, y: 44)
                        .allowsHitTesting(false)
                    LinearGradient(colors: [Color.white.opacity(0.13), .clear],
                                   startPoint: .topLeading, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("Active certificate").uppercased())
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .tracking(1.3)
                                    .foregroundColor(.white.opacity(0.62))
                                Text(c.nickname)
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(c.profile.teamName.isEmpty ? c.details.organization : c.profile.teamName)
                                    .font(SayoType.caption)
                                    .foregroundColor(.white.opacity(0.62))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Button {
                                Haptics.selection()
                                state.tab = 1
                            } label: {
                                Text(L("Change"))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color.white.opacity(0.16)))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.6))
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(c))
                                .frame(width: 7, height: 7)
                                .shadow(color: statusColor(c).opacity(0.8), radius: 4)
                            Text(statusText(c))
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            Text("·").foregroundColor(.white.opacity(0.35))
                            Text(LF("%d days left", c.daysLeft))
                                .font(SayoType.micro)
                                .foregroundColor(.white.opacity(0.68))
                            Spacer()
                            Pill(text: c.profile.isWildcard ? L("Wildcard") : L("Explicit ID"),
                                 color: .white.opacity(0.85))
                                .opacity(0.9)
                        }

                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.14))
                                    Capsule()
                                        .fill(Color.white.opacity(0.86))
                                        .frame(width: max(4, geo.size.width * validity(c)))
                                }
                            }
                            .frame(height: 4)
                            HStack {
                                Text(c.ocspChecked == nil ? L("Checking…") : L("Verified with Apple"))
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.48))
                                Spacer()
                                Text(LF("Expires %@", dateFormatter.string(from: c.expires)))
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.58))
                            }
                        }
                    }
                    .padding(18)
                }
                .frame(minHeight: 178)
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .onTapGesture {
                Haptics.light()
                state.tab = 1
            }
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: L("Manage")) { state.tab = 1 }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 13) {
                    IconBadge(symbol: "key.fill", tint: Theme.coral, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Add a certificate"))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(Theme.textPrimary)
                        Text(L("Import a .p12 with its profile, or sign in with a free Apple ID."))
                            .font(SayoType.caption)
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button {
                    Haptics.light()
                    state.tab = 1
                } label: {
                    HStack(spacing: 7) {
                        Text(L("Add certificate"))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .flipsForRightToLeftLayoutDirection(true)
                    }
                }
                .buttonStyle(SmallButtonStyle())
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .stroke(Theme.coral.opacity(0.16), lineWidth: 0.8)
                    )
                    .shadow(color: Theme.coral.opacity(0.07), radius: 20, y: 10)
            )
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Quick actions"))
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    QuickActionTile(title: L("Import IPA"), subtitle: L("From Files"), symbol: "tray.and.arrow.down.fill", tint: Theme.coral) {
                        importing = true
                    }
                    QuickActionTile(title: L("Certificates"), subtitle: L("Manage certificates"), symbol: "checkmark.seal.fill", tint: Theme.success) {
                        state.tab = 1
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 10) {
                    QuickActionTile(title: L("From URL"), subtitle: L("Download from URL"), symbol: "link", tint: Theme.lilac) {
                        urlPrompt = true
                    }
                    QuickActionTile(title: L("Browse sources"), subtitle: L("Discover apps"), symbol: "globe", tint: Theme.info) {
                        state.tab = 2
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Overview"), accessory: L("On this iPhone"))
            HStack(spacing: 8) {
                MetricTile(value: "\(state.library.count)", label: L("Imported"), tint: Theme.coral)
                MetricTile(value: "\(state.signed.count)", label: L("Signed"), tint: Theme.success)
                MetricTile(value: "\(state.certificates.count)", label: L("Certificates"), tint: Theme.lilac)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
        )
    }

    // MARK: - Recent activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Recent activity"), accessory: L("Signed apps"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(state.signed.prefix(6)) { app in
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { segment = 1 }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                AppIconView(image: signedIcon(app), size: 42)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text(app.signedAt.sayoRelative)
                                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 132, alignment: .leading)
                            .padding(11)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Theme.surface)
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.6))
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Library"))
                    .font(SayoType.display)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(segment == 0 ? "\(filteredLibrary.count)" : "\(filteredSigned.count)")
                    .font(SayoType.numberSmall)
                    .foregroundColor(Theme.textTertiary)
            }
            SearchField(text: $search, placeholder: L("Search apps"))
            SayoSegmentedControl(selection: $segment, items: [
                (L("Imported"), state.library.count),
                (L("Signed apps"), state.signed.count)
            ])

            ForEach(state.downloads) { d in
                DownloadCard(task: d)
            }

            if segment == 0 {
                if filteredLibrary.isEmpty && state.downloads.isEmpty {
                    EmptyLibraryView(searching: !search.isEmpty) {
                        importing = true
                    } secondary: {
                        state.tab = 2
                    }
                } else if filteredLibrary.isEmpty {
                    EmptyState(title: L("Nothing found"), subtitle: L("Try another search."), symbol: "magnifyingglass")
                }
                ForEach(filteredLibrary) { app in
                    LibraryRow(app: app)
                        .contextMenu {
                            Button { state.pendingSign = app } label: { Label(L("Sign"), systemImage: "signature") }
                            Button { Task { await state.addUnsigned(app) } } label: {
                                Label(L("Install without re-signing"), systemImage: "arrow.down.app")
                            }
                            Button(role: .destructive) { state.deleteLibrary(app) } label: { Label(L("Delete"), systemImage: "trash") }
                        }
                }
            } else {
                if filteredSigned.isEmpty {
                    if search.isEmpty {
                        EmptySignedView(hasLibrary: !state.library.isEmpty) {
                            if let first = state.library.first { state.pendingSign = first } else { importing = true }
                        }
                    } else {
                        EmptyState(title: L("Nothing found"), subtitle: L("Try another search."), symbol: "magnifyingglass")
                    }
                }
                ForEach(filteredSigned) { app in
                    SignedRow(app: app, share: $share, setup: $setup)
                        .contextMenu {
                            Button { share = state.ipaURL(app) } label: { Label(L("Share IPA"), systemImage: "square.and.arrow.up") }
                            Button(role: .destructive) { state.deleteSigned(app) } label: { Label(L("Delete"), systemImage: "trash") }
                        }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    func signedIcon(_ app: SignedApp) -> UIImage? {
        app.libraryID
            .flatMap { id in state.library.first { $0.id == id } }
            .flatMap { state.icon(for: $0) }
    }

    func statusColor(_ cert: StoredCertificate) -> Color {
        if cert.isExpired { return Color.white.opacity(0.55) }
        switch cert.ocsp {
        case .good: return Color(red: 0.45, green: 0.91, blue: 0.68)
        case .revoked: return Color(red: 1, green: 0.45, blue: 0.50)
        default: return Color(red: 1, green: 0.78, blue: 0.44)
        }
    }

    func statusText(_ cert: StoredCertificate) -> String {
        if cert.isExpired { return L("Expired") }
        switch cert.ocsp {
        case .good: return L("Signed")
        case .revoked: return L("Revoked")
        case .unknown: return L("Unknown")
        case .unchecked: return L("Checking…")
        }
    }

    func validity(_ cert: StoredCertificate) -> CGFloat {
        let total = cert.expires.timeIntervalSince(cert.details.notBefore)
        guard total > 0 else { return 0 }
        return CGFloat(max(0.02, min(1, cert.expires.timeIntervalSinceNow / total)))
    }
}

// MARK: - Supporting views

struct ShareItem: Identifiable {
    var id: String { url.path }
    let url: URL
}

struct StatusDot: View {
    let status: OCSPStatus
    let expired: Bool

    var color: Color {
        if expired { return Theme.textTertiary }
        switch status {
        case .good: return Theme.success
        case .revoked: return Theme.danger
        default: return Theme.warning
        }
    }

    var text: String {
        if expired { return L("Expired") }
        switch status {
        case .good: return L("Signed")
        case .revoked: return L("Revoked")
        case .unknown: return L("Unknown")
        case .unchecked: return L("Checking…")
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.55), radius: 3)
            Text(text)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
    }
}

struct LibraryRow: View {
    @EnvironmentObject var state: AppState
    let app: LibraryApp

    var body: some View {
        Button {
            Haptics.light()
            state.pendingSign = app
        } label: {
            HStack(spacing: 13) {
                AppIconView(image: state.icon(for: app), size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
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
                Spacer(minLength: 4)
                VStack(spacing: 5) {
                    ZStack {
                        Circle().fill(Theme.coral.opacity(0.11)).frame(width: 36, height: 36)
                        Image(systemName: "signature")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.coral)
                    }
                    Text(L("Sign"))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.coral)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .stroke(Theme.border, lineWidth: 0.7)
                    )
                    .shadow(color: Color.black.opacity(0.035), radius: 12, y: 5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text("\(app.name), \(L("Sign"))"))
        .accessibilityIdentifier("library.row." + app.bundleID)
    }
}

struct SignedRow: View {
    @EnvironmentObject var state: AppState
    let app: SignedApp
    @Binding var share: URL?
    @Binding var setup: Bool
    @State private var installing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 13) {
                AppIconView(image: app.libraryID.flatMap { id in state.library.first { $0.id == id } }.flatMap { state.icon(for: $0) }, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(app.certificateName)
                        .font(SayoType.micro)
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Pill(text: "v" + app.version)
                        if !app.tweaks.isEmpty { Pill(text: LF("%d tweaks", app.tweaks.count), color: Theme.lilac) }
                        if app.container == true { Pill(text: L("Inside SayoSign"), color: Theme.mint) }
                        if app.viaAppleID == true { Pill(text: expiryText, color: expiryColor) }
                    }
                }
                Spacer(minLength: 4)
            }

            DividerSoft()

            HStack(spacing: 8) {
                Text(L("Signed"))
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
                Text(app.signedAt.sayoRelative)
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Button { share = state.ipaURL(app) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.surfaceInset.opacity(0.8)))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L("Share IPA"))

                if app.container == true {
                    Button { runInside() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill").font(.system(size: 10, weight: .bold))
                            Text(L("Run"))
                        }
                    }
                    .buttonStyle(SmallButtonStyle())
                } else {
                    Button { Task { await install() } } label: {
                        HStack(spacing: 5) {
                            if installing {
                                ProgressView().tint(.white).scaleEffect(0.65)
                            } else {
                                Image(systemName: "arrow.down.app.fill").font(.system(size: 11, weight: .semibold))
                            }
                            Text(L("Install"))
                        }
                    }
                    .buttonStyle(SmallButtonStyle())
                    .disabled(installing)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.7)
                )
                .shadow(color: Color.black.opacity(0.035), radius: 12, y: 5)
        )
    }

    var expiryText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: app.signedAt.addingTimeInterval(7 * 24 * 3600)).day ?? 0
        return days <= 0 ? L("Expired") : LF("%d days left", days)
    }

    var expiryColor: Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: app.signedAt.addingTimeInterval(7 * 24 * 3600)).day ?? 0
        return days <= 2 ? Theme.danger : (days <= 4 ? Theme.warning : Theme.success)
    }

    func runInside() {
        do {
            state.show(LF("%@ starts when you open SayoSign again", app.name))
            try Container.run(app, ipa: state.ipaURL(app))
        } catch {
            state.show(error.localizedDescription)
        }
    }

    func install() async {
        installing = true
        defer { installing = false }
        do {
            if try await Installer.install(app, state: state) {
                state.show(LF("%@ is installed", app.name))
                Haptics.success()
            } else {
                state.show(L("Confirm the install prompt, keep SayoSign open until the icon finishes"))
            }
        } catch is InstallNeedsSetup {
            setup = true
        } catch {
            state.show(error.localizedDescription)
            Haptics.error()
        }
    }
}

struct DownloadCard: View {
    let task: DownloadTask
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Theme.border, lineWidth: 3).frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: max(0.01, task.progress))
                    .stroke(Theme.inkGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.coral)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(SayoType.bodyStrong)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(task.status)
                    Text("·")
                    Text("\(Int(task.progress * 100))%")
                }
                .font(SayoType.micro)
                .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Text("\(Int(task.progress * 100))%")
                .font(SayoType.numberSmall)
                .foregroundColor(Theme.coral)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
        )
    }
}

struct EmptyLibraryView: View {
    let searching: Bool
    let action: () -> Void
    let secondary: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.coral.opacity(0.07)).frame(width: 104, height: 104)
                Circle().stroke(Theme.coral.opacity(0.10), lineWidth: 1).frame(width: 78, height: 78)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 6) {
                Text(searching ? L("Nothing found") : L("No apps yet"))
                    .font(SayoType.title3)
                    .foregroundColor(Theme.textPrimary)
                Text(searching ? L("Try another search.") : L("Start your library with an IPA from Files, a download link, or a repository."))
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 9) {
                Button(action: action) { Text(L("Import from Files")) }
                    .buttonStyle(SmallButtonStyle())
                Button(action: secondary) { Text(L("Browse sources")) }
                    .buttonStyle(SmallButtonStyle(filled: false))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Theme.border))
        )
    }
}

struct EmptySignedView: View {
    let hasLibrary: Bool
    let action: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.success.opacity(0.08)).frame(width: 104, height: 104)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Theme.success.opacity(0.8))
            }
            VStack(spacing: 6) {
                Text(L("Nothing signed yet"))
                    .font(SayoType.title3)
                    .foregroundColor(Theme.textPrimary)
                Text(L("Signed apps appear here, ready to install or share."))
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: action) {
                Text(hasLibrary ? L("Sign your first app") : L("Import from Files"))
            }
            .buttonStyle(SmallButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Theme.border))
        )
    }
}

struct DownloadURLSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @Binding var urlText: String
    let onDownload: (URL) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground()
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "link", tint: Theme.lilac, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("Download from URL"))
                                .font(SayoType.title)
                                .foregroundColor(Theme.textPrimary)
                            Text(L("Paste a direct link to an .ipa file."))
                                .font(SayoType.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("URL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.9)
                            .foregroundColor(Theme.textTertiary)
                        TextField("https://…/app.ipa", text: $urlText)
                            .font(SayoType.body)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .focused($focused)
                            .padding(13)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .fill(Theme.surfaceInset.opacity(0.75))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                            )
                    }
                    Button {
                        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let u = URL(string: trimmed), u.scheme != nil {
                            Haptics.medium()
                            onDownload(u)
                            urlText = ""
                            dismiss()
                        } else {
                            state.show(L("Invalid URL"))
                            Haptics.error()
                        }
                    } label: {
                        Label(L("Download"), systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(urlText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)
                    .animation(.easeInOut(duration: 0.2), value: urlText.isEmpty)
                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .navigationViewStyle(.stack)
    }
}
