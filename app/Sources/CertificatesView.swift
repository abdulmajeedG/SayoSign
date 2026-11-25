import SwiftUI
import UniformTypeIdentifiers

struct CertificatesView: View {
    @EnvironmentObject var state: AppState
    @State private var adding = false
    @State private var appleID = false
    @State private var checking = false

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground()
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        header
                        title
                        actions
                        if state.certificates.isEmpty {
                            emptyState
                        } else {
                            ForEach(state.certificates) { c in
                                CertificateCard(cert: c)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
                .refreshable { await state.refreshAllOCSP() }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $adding) {
                ImportCertificateView(prefillP12: nil, prefillProfile: nil).environmentObject(state)
            }
            .sheet(isPresented: $appleID) {
                AppleIDView().environmentObject(state)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        BrandHeader(compact: true, trailing: AnyView(
            Button {
                Haptics.light()
                Task {
                    checking = true
                    await state.refreshAllOCSP()
                    checking = false
                    state.show(L("Certificate status updated"))
                    Haptics.success()
                }
            } label: {
                if checking {
                    ProgressView().scaleEffect(0.8).frame(width: 40, height: 40)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 0.7)))
                }
            }
            .disabled(checking)
            .accessibilityLabel(L("Refresh status"))
        ))
    }

    private var title: some View {
        PageTitle(eyebrow: L("Security"),
                  title: L("Certificates"),
                  subtitle: L("Your signing identities, at a glance."))
            .padding(.top, 2)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.light()
                adding = true
            } label: {
                VStack(alignment: .leading, spacing: 11) {
                    IconBadge(symbol: "doc.badge.plus", tint: Theme.coral, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Import .p12"))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text(L("Certificate + profile"))
                            .font(SayoType.micro)
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                )
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("certificates.import")

            Button {
                Haptics.light()
                appleID = true
            } label: {
                VStack(alignment: .leading, spacing: 11) {
                    IconBadge(symbol: "applelogo", tint: Theme.textPrimary, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Apple ID"))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text(L("Free or paid account"))
                            .font(SayoType.micro)
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                )
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("certificates.appleid")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.coral.opacity(0.07)).frame(width: 108, height: 108)
                Circle().stroke(Theme.coral.opacity(0.1), lineWidth: 1).frame(width: 82, height: 82)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 6) {
                Text(L("No certificates"))
                    .font(SayoType.title3)
                    .foregroundColor(Theme.textPrimary)
                Text(L("Import a .p12 with its .mobileprovision, or sign in with a free Apple ID."))
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { adding = true } label: {
                Text(L("Import .p12"))
            }
            .buttonStyle(SmallButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundColor(Theme.border)
                )
        )
    }
}

struct CertificateCard: View {
    @EnvironmentObject var state: AppState
    let cert: StoredCertificate
    @State private var expanded = false
    @State private var confirmDelete = false
    @State private var manage = false
    @State private var showDevices = false

    var selected: Bool { state.selectedCertificate?.id == cert.id }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.selection()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { expanded.toggle() }
            } label: {
                VStack(spacing: 13) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Theme.inkGradient)
                                .frame(width: 48, height: 48)
                                .opacity(cert.isExpired ? 0.45 : 1)
                            Image(systemName: cert.fromAppleID ? "applelogo" : "seal.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text(cert.nickname)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                if cert.fromAppleID {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            Text(cert.details.subject)
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 7) {
                            if selected {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(L("Selected"))
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(Theme.success)
                            } else {
                                Text(L("Use"))
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.coral)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Theme.coral.opacity(0.1)))
                                    .onTapGesture {
                                        Haptics.selection()
                                        state.settings.selectedCertificate = cert.id
                                    }
                            }
                            Chevron(expanded: expanded)
                        }
                    }

                    // Validity bar
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.surfaceInset)
                                Capsule()
                                    .fill(cert.isExpired ? AnyShapeStyle(Theme.textTertiary) : AnyShapeStyle(Theme.inkGradient))
                                    .frame(width: max(5, geo.size.width * validity))
                            }
                        }
                        .frame(height: 5)
                        HStack(spacing: 6) {
                            StatusDot(status: cert.ocsp, expired: cert.isExpired)
                            Text("·").foregroundColor(Theme.textTertiary)
                            Text(LF("%d days left", cert.daysLeft))
                                .font(SayoType.micro)
                                .foregroundColor(cert.daysLeft < 14 ? Theme.warning : Theme.textSecondary)
                            Spacer()
                            Text(LF("Expires %@", dateFormatter.string(from: cert.expires)))
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    HStack(spacing: 5) {
                        Pill(text: cert.profile.isWildcard ? L("Wildcard") : L("Explicit ID"), color: Theme.textSecondary)
                        Pill(text: cert.profile.teamName.isEmpty ? cert.details.organization : cert.profile.teamName, color: Theme.lilac)
                        Spacer()
                        if let r = cert.revokedAt {
                            Text(LF("Revoked on %@", dateFormatter.string(from: r)))
                                .font(SayoType.micro)
                                .foregroundColor(Theme.danger)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 11) {
                    DividerSoft().padding(.horizontal, 15)

                    VStack(spacing: 9) {
                        SayoInfoRow(L("Team"), "\(cert.profile.teamName) (\(cert.details.team))")
                        SayoInfoRow(L("Type"), cert.details.subject.components(separatedBy: ":").first ?? "")
                        SayoInfoRow(L("Issuer"), cert.details.issuer)
                        SayoInfoRow(L("Serial"), cert.details.serial, mono: true)
                        SayoInfoRow(L("Certificate expires"), dateFormatter.string(from: cert.details.notAfter))
                        SayoInfoRow(L("Profile"), cert.profile.name)
                        SayoInfoRow(L("App ID"), cert.profile.appID, mono: true)
                        SayoInfoRow(L("Profile expires"), dateFormatter.string(from: cert.profile.expiration))
                        SayoInfoRow(L("Devices"), cert.profile.allDevices ? L("All (enterprise)") : "\(cert.profile.devices.count)")
                        SayoInfoRow(L("Debuggable"), cert.profile.getTaskAllow ? L("Yes") : L("No"))
                        if let d = cert.ocspChecked {
                            SayoInfoRow(L("Checked"), RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()))
                        }
                    }
                    .padding(.horizontal, 15)

                    if !cert.profile.devices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showDevices.toggle() }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(showDevices ? L("Hide UDIDs") : L("Show UDIDs"))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .rotationEffect(.degrees(showDevices ? 180 : 0))
                                }
                                .font(SayoType.captionStrong)
                                .foregroundColor(Theme.coral)
                            }
                            if showDevices {
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(cert.profile.devices, id: \.self) { u in
                                        Text(u + (u.uppercased() == state.settings.udid.uppercased() ? "  ← " + L("This iPhone") : ""))
                                            .font(SayoType.monoSmall)
                                            .foregroundColor(Theme.textSecondary)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous).fill(Theme.surfaceInset.opacity(0.7)))
                            }
                        }
                        .padding(.horizontal, 15)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Entitlements"))
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(Theme.textTertiary)
                        Text(cert.profile.entitlementKeys
                            .map { $0.replacingOccurrences(of: "com.apple.developer.", with: "") }
                            .joined(separator: " · "))
                            .font(SayoType.micro)
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous).fill(Theme.surfaceInset.opacity(0.55)))
                    .padding(.horizontal, 15)

                    HStack(spacing: 8) {
                        if cert.fromAppleID {
                            Button { manage = true } label: { Label(L("Manage Apple ID account"), systemImage: "person.badge.key") }
                                .buttonStyle(SmallButtonStyle(filled: false))
                        }
                        Spacer()
                        Button { Task { await state.refreshOCSP(cert) } } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(SmallButtonStyle(filled: false))
                        .accessibilityLabel(L("Check now"))
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(SmallButtonStyle(filled: false))
                        .accessibilityLabel(L("Delete"))
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(selected ? Theme.coral.opacity(0.35) : Theme.border, lineWidth: selected ? 1.2 : 0.7)
                )
                .shadow(color: selected ? Theme.coral.opacity(0.08) : Color.black.opacity(0.035), radius: 16, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .sheet(isPresented: $manage) { AppleAccountView(cert: cert).environmentObject(state) }
        .confirmationDialog(L("Delete this certificate?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("Delete"), role: .destructive) {
                Haptics.warning()
                state.deleteCertificate(cert)
            }
        }
    }

    var validity: CGFloat {
        let total = cert.expires.timeIntervalSince(cert.details.notBefore)
        guard total > 0 else { return 0 }
        return CGFloat(max(0.015, min(1, cert.expires.timeIntervalSinceNow / total)))
    }
}

// MARK: - Import certificate

struct ImportCertificateView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State var prefillP12: URL?
    @State var prefillProfile: URL?
    @State private var p12: URL?
    @State private var profile: URL?
    @State private var password = ""
    @State private var nickname = ""
    @State private var error: String?

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HStack(spacing: 14) {
                            IconBadge(symbol: "key.fill", tint: Theme.coral, size: 50)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("Add certificate"))
                                    .font(SayoType.title)
                                    .foregroundColor(Theme.textPrimary)
                                Text(L("Import a .p12 with its .mobileprovision."))
                                    .font(SayoType.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            SectionLabel(title: L("Files"))
                                .padding(.bottom, 8)
                            fileRow(symbol: "key.fill", title: L("Certificate (.p12)"), url: p12)
                            DividerSoft().padding(.vertical, 4)
                            fileRow(symbol: "doc.text.fill", title: L("Profile (.mobileprovision)"), url: profile)
                            Text(L("Tip: you can select the .p12 and the .mobileprovision together."))
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary)
                                .padding(.top, 10)
                        }
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: L("Details"))
                            SayoTextField(title: L("Password"), placeholder: "", text: $password, secure: true)
                            SayoTextField(title: L("Nickname (optional)"), placeholder: "", text: $nickname)
                        }
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                        )

                        if let e = error {
                            BannerView(kind: .error, text: e)
                        }

                        Button {
                            Haptics.medium()
                            save()
                        } label: {
                            Label(L("Import"), systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(p12 == nil || profile == nil)
                        .opacity(p12 == nil || profile == nil ? 0.55 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
            .onAppear {
                if p12 == nil { p12 = prefillP12 }
                if profile == nil { profile = prefillProfile }
                CertificateImportCoordinator.shared.p12 = nil
                CertificateImportCoordinator.shared.profile = nil
                if let p = p12 { autoProfile(near: p) }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func fileRow(symbol: String, title: String, url: URL?) -> some View {
        Button { pickFiles() } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: symbol, tint: url == nil ? Theme.textTertiary : Theme.success, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SayoType.bodyStrong)
                        .foregroundColor(Theme.textPrimary)
                    Text(url?.lastPathComponent ?? L("Choose"))
                        .font(SayoType.micro)
                        .foregroundColor(url == nil ? Theme.textTertiary : Theme.success)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: url == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(url == nil ? Theme.coral : Theme.success)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func pickFiles() {
        FilePicker.shared.pick([.item], multiple: true) { urls in
            error = nil
            for u in urls { take(u) }
        }
    }

    func take(_ u: URL) {
        let scoped = u.startAccessingSecurityScopedResource()
        defer { if scoped { u.stopAccessingSecurityScopedResource() } }
        var data: Data?
        var readError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: u, options: [], error: &readError) { url in
            data = try? Data(contentsOf: url)
        }
        guard let d = data, !d.isEmpty else {
            error = L("Cannot read the selected files") + (readError.map { ": " + $0.localizedDescription } ?? "")
            return
        }
        let ext = u.pathExtension.lowercased()
        let looksLikeProfile = ext == "mobileprovision" || d.range(of: Data("<plist".utf8)) != nil
        let looksLikeP12 = ext == "p12" || ext == "pfx" || (!looksLikeProfile && d.first == 0x30)
        let isProfile = looksLikeProfile && !(ext == "p12" || ext == "pfx")
        guard isProfile || looksLikeP12 else {
            error = L("This is not a .p12 or .mobileprovision file") + ": " + u.lastPathComponent
            return
        }
        let dst = Paths.work.appendingPathComponent(UUID().uuidString + "-" + u.lastPathComponent)
        do {
            try d.write(to: dst)
        } catch {
            self.error = error.localizedDescription
            return
        }
        try? FileManager.default.removeItem(at: u)
        if isProfile { profile = dst } else { p12 = dst }
    }

    func autoProfile(near p: URL) {
        guard profile == nil else { return }
        let dir = p.deletingLastPathComponent()
        if let f = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .first(where: { $0.pathExtension == "mobileprovision" }) {
            profile = f
        }
    }

    func save() {
        guard let p = p12, let m = profile,
              let pd = try? Data(contentsOf: p), let md = try? Data(contentsOf: m) else {
            error = L("Cannot read the selected files")
            return
        }
        do {
            _ = try state.addCertificate(p12: pd, profile: md, password: password, nickname: nickname)
            state.show(L("Certificate added"))
            Haptics.success()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}
