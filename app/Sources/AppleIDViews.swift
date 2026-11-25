import SwiftUI

// MARK: - Apple ID sign-in

struct AppleIDView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var udid = ""
    @State private var step = 0
    @State private var working = false
    @State private var log: [String] = []
    @State private var error: String?
    @State private var auth: GSAuth?
    @State private var login: GSAuth.LoginResult?
    @State private var factor: SecondFactor = .trustedDevice
    @State private var teams: [[String: Any]] = []
    @State private var session: AppleSession?
    @State private var anisette: Anisette?
    @State private var revokeChoices: [[String: Any]] = []
    @State private var revokeSelected: Set<String> = []
    @State private var pendingTeam: [String: Any]?

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground(accent: Theme.lilac)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        topBar
                        hero
                        if step <= 2 { stepRail }
                        content
                        if !log.isEmpty { logCard }
                        if let e = error { BannerView(kind: .error, text: e) }
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear { udid = state.settings.udid }
            .onReceive(NotificationCenter.default.publisher(for: .sayoUDID)) { n in
                if let v = n.object as? String { udid = v }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(working)
    }

    private var topBar: some View {
        HStack {
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
            .disabled(working)
            .accessibilityLabel(L("Close"))
            .accessibilityIdentifier("appleid.close")
            Spacer()
            Text(L("Apple ID"))
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            BrandMark(size: 34)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.surface)
                    .frame(width: 82, height: 82)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 0.7))
                    .shadow(color: Color.black.opacity(0.05), radius: 14, y: 6)
                Image(systemName: "applelogo")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 4) {
                Text(L("Sign in with Apple ID"))
                    .font(SayoType.title)
                    .foregroundColor(Theme.textPrimary)
                Text(L("Your password is sent only to Apple. Free accounts get 7-day certificates and up to 3 apps at a time."))
                    .font(SayoType.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.top, 6)
    }

    private var stepRail: some View {
        HStack(spacing: 0) {
            ForEach(Array([L("Account"), L("Verification"), L("Team")].enumerated()), id: \.offset) { index, title in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index <= step ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.surfaceInset))
                            .frame(width: 22, height: 22)
                        if index < step {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(index == step ? .white : Theme.textTertiary)
                        }
                    }
                    Text(title)
                        .font(.system(size: 11, weight: index == step ? .semibold : .medium, design: .rounded))
                        .foregroundColor(index <= step ? Theme.textPrimary : Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if index < 2 {
                    Rectangle()
                        .fill(index < step ? Theme.coral.opacity(0.5) : Theme.border)
                        .frame(height: 1.5)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surface.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
        )
    }

    @ViewBuilder
    private var content: some View {
        if step == 0 {
            accountStep
        } else if step == 1 {
            codeStep
        } else if step == 2 {
            teamStep
        } else {
            revokeStep
        }
    }

    private var accountStep: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: L("Apple ID"))
                SayoTextField(title: L("Apple ID"), placeholder: "email@icloud.com", text: $email,
                              keyboard: .emailAddress, capitalization: .never)
                SayoTextField(title: L("Password"), placeholder: L("Password"), text: $password, secure: true)
            }
            .padding(15)
            .background(panel)

            VStack(alignment: .leading, spacing: 11) {
                SectionLabel(title: L("Anisette server"),
                             subtitle: L("Apple only accepts Mac-based anisette servers since October 2026."))
                Menu {
                    ForEach(Anisette.presets, id: \.url) { p in
                        Button {
                            state.settings.anisetteURL = p.url
                            Haptics.selection()
                        } label: {
                            Label(p.name, systemImage: state.settings.anisetteURL == p.url ? "checkmark" : "circle")
                        }
                    }
                    if !Anisette.presets.contains(where: { $0.url == state.settings.anisetteURL }) {
                        Button {
                        } label: {
                            Label(state.settings.anisetteURL, systemImage: "checkmark")
                        }
                    }
                } label: {
                    HStack(spacing: 11) {
                        IconBadge(symbol: "server.rack", tint: Theme.info, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L("Server"))
                                .font(SayoType.micro)
                                .foregroundColor(Theme.textTertiary)
                            Text(anisetteName)
                                .font(SayoType.bodyStrong)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.surfaceInset.opacity(0.55)))
                }
            }
            .padding(15)
            .background(panel)

            VStack(alignment: .leading, spacing: 11) {
                SectionLabel(title: "UDID")
                SayoTextField(title: "UDID", placeholder: "00008110-000000000000001E", text: $udid,
                              capitalization: .characters, mono: true)
                Button { detectUDID() } label: {
                    Label(L("Detect UDID automatically"), systemImage: "iphone.radiowaves.left.and.right")
                        .font(SayoType.captionStrong)
                        .foregroundColor(Theme.coral)
                }
                Text(L("Apple needs this iPhone's UDID. Tap Detect: Safari downloads a profile, open Settings → Profile Downloaded → Install, and you come back here with the UDID filled in."))
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
            .background(panel)

            Button {
                Haptics.medium()
                Task { await start() }
            } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.white).scaleEffect(0.8) }
                    Text(L("Sign in"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working || email.isEmpty || password.isEmpty || udid.count < 20)
            .opacity(working || email.isEmpty || password.isEmpty || udid.count < 20 ? 0.55 : 1)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: L("Two-factor code"))
                TextField("123456", text: $code)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.surfaceInset.opacity(0.65))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                    )
                Text(factor == .sms ? L("A code was sent by SMS.") : L("Check your other Apple device for the code."))
                    .font(SayoType.caption)
                    .foregroundColor(Theme.textSecondary)
                Button {
                    Haptics.light()
                    Task { await switchToSMS() }
                } label: {
                    Label(L("Send SMS instead"), systemImage: "message.fill")
                        .font(SayoType.captionStrong)
                        .foregroundColor(Theme.coral)
                }
            }
            .padding(16)
            .background(panel)

            Button {
                Haptics.medium()
                Task { await verify() }
            } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.white).scaleEffect(0.8) }
                    Text(L("Verify"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working || code.count < 6)
            .opacity(working || code.count < 6 ? 0.55 : 1)
        }
    }

    private var teamStep: some View {
        VStack(spacing: 12) {
            SectionLabel(title: L("Choose a team"))
            VStack(spacing: 0) {
                ForEach(teams.indices, id: \.self) { i in
                    let t = teams[i]
                    Button {
                        Haptics.selection()
                        Task { await finish(team: t) }
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(symbol: "person.2.fill", tint: Theme.lilac, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t["name"] as? String ?? "Team")
                                    .font(SayoType.bodyStrong)
                                    .foregroundColor(Theme.textPrimary)
                                Text((t["teamId"] as? String ?? "") + " · " + (t["type"] as? String ?? ""))
                                    .font(SayoType.micro)
                                    .foregroundColor(Theme.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if working {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.textTertiary)
                                    .flipsForRightToLeftLayoutDirection(true)
                            }
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(working)
                    if i < teams.count - 1 { DividerSoft() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(panel)
        }
    }

    private var revokeStep: some View {
        VStack(spacing: 13) {
            SectionLabel(title: L("Revoke certificates"),
                         subtitle: L("This Apple ID already has as many development certificates as Apple allows. Choose which to revoke; apps signed with a revoked certificate stop opening."))
            VStack(spacing: 0) {
                ForEach(revokeChoices.indices, id: \.self) { i in
                    let c = revokeChoices[i]
                    let serial = c["serialNumber"] as? String ?? ""
                    Button {
                        Haptics.selection()
                        if revokeSelected.contains(serial) { revokeSelected.remove(serial) } else { revokeSelected.insert(serial) }
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: revokeSelected.contains(serial) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(revokeSelected.contains(serial) ? Theme.coral : Theme.textTertiary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c["machineName"] as? String ?? c["name"] as? String ?? L("Certificate"))
                                    .font(SayoType.bodyStrong)
                                    .foregroundColor(Theme.textPrimary)
                                Text(serial)
                                    .font(SayoType.monoSmall)
                                    .foregroundColor(Theme.textTertiary)
                                if let d = c["expirationDate"] as? Date {
                                    Text(LF("Expires %@", dateFormatter.string(from: d)))
                                        .font(SayoType.micro)
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < revokeChoices.count - 1 { DividerSoft() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(panel)

            Button {
                Haptics.warning()
                Task { await revokeAndContinue() }
            } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.white).scaleEffect(0.8) }
                    Text(L("Revoke and continue"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working || revokeSelected.isEmpty)
            .opacity(working || revokeSelected.isEmpty ? 0.55 : 1)
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: L("Progress"))
            ForEach(log.indices, id: \.self) { i in
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.success)
                    Text(log[i])
                        .font(SayoType.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
    }

    private var anisetteName: String {
        Anisette.presets.first { $0.url == state.settings.anisetteURL }?.name ?? state.settings.anisetteURL
    }

    // MARK: - Logic (unchanged)

    func add(_ s: String) { log.append(s) }

    func revokeAndContinue() async {
        guard let s = session, let ani = anisette, let team = pendingTeam, let teamID = team["teamId"] as? String else { return }
        working = true
        error = nil
        do {
            let api = DeveloperAPI(session: s, anisette: ani)
            for serial in revokeSelected {
                _ = try await api.call("revokeDevelopmentCert", ["teamId": teamID, "serialNumber": serial])
            }
            add(LF("Revoked %d certificate(s)", revokeSelected.count))
        } catch {
            self.error = error.localizedDescription
            working = false
            return
        }
        working = false
        step = 2
        await finish(team: team)
    }

    func detectUDID() {
        let server = InstallServer.shared
        do { try server.startPlain(port: state.settings.serverPort) } catch {
            self.error = error.localizedDescription
            return
        }
        server.keepAlive(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { server.keepAlive(false) }
        if let u = URL(string: "\(server.httpBase)/udid.mobileconfig") { UIApplication.shared.open(u) }
    }

    func start() async {
        working = true
        error = nil
        defer { working = false }
        state.settings.udid = udid.trimmingCharacters(in: .whitespaces).uppercased()
        do {
            let ani = try await Anisette.fetch(state.settings.anisetteURL)
            anisette = ani
            add(L("Got anisette data") + " (\(ani.version)\(ani.isMacClient ? ", Mac" : ""))")
            let a = GSAuth(anisette: ani, email: email.trimmingCharacters(in: .whitespaces), password: password)
            auth = a
            let r: GSAuth.LoginResult
            do {
                r = try await a.login()
            } catch let e as SayoError where e.message.contains("-45061") || e.message.contains("-80045") || e.message.contains("-80046") {
                ani.reset()
                try await ani.refresh()
                add(L("Anisette was reset"))
                r = try await a.login()
            }
            login = r
            add(L("Password accepted"))
            if let f = r.needs2FA {
                factor = f
                try await a.requestCode(r, kind: f)
                step = 1
                return
            }
            try await afterLogin(r)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func switchToSMS() async {
        guard let a = auth, let r = login else { return }
        factor = .sms
        do { try await a.requestCode(r, kind: .sms) } catch { self.error = error.localizedDescription }
    }

    func verify() async {
        guard let a = auth, let r = login else { return }
        working = true
        error = nil
        defer { working = false }
        do {
            try await a.submitCode(code.trimmingCharacters(in: .whitespaces), r: r, kind: factor)
            add(L("Code accepted"))
            let again = try await a.login()
            if again.needs2FA != nil { throw SayoError(L("Apple still asks for a code. Try signing in again.")) }
            login = again
            try await afterLogin(again)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func afterLogin(_ r: GSAuth.LoginResult) async throws {
        guard let a = auth, let ani = anisette else { return }
        let s = try await a.xcodeToken(r)
        session = s
        add(L("Signed in to developer services"))
        let api = DeveloperAPI(session: s, anisette: ani)
        let t = try await api.teams()
        if t.isEmpty { throw SayoError(L("This Apple ID has no developer team")) }
        if t.count == 1 {
            await finish(team: t[0])
        } else {
            teams = t
            step = 2
        }
    }

    func finish(team: [String: Any]) async {
        guard let s = session, let ani = anisette, let teamID = team["teamId"] as? String else { return }
        working = true
        error = nil
        defer { working = false }
        do {
            let api = DeveloperAPI(session: s, anisette: ani)
            try await api.ensureDevice(team: teamID, udid: state.settings.udid)
            add(L("Device registered"))
            let id = UUID()
            let tag = AppleAccount.accountKeyTag(s.email)
            let key = try LocalCA.key(tag: Data(tag.utf8)) ?? LocalCA.makeKey(tag: Data(tag.utf8))
            let der: Data
            switch try await api.obtainCertificate(team: teamID, key: key) {
            case .ready(let d):
                der = d
            case .limitReached(let existing):
                revokeChoices = existing
                revokeSelected = []
                pendingTeam = team
                step = 3
                return
            }
            Keychain.set(tag, for: "appleid.keytag." + id.uuidString)
            add(L("Certificate ready"))
            guard let details = SayoCore.certDetails(der) else { throw SayoError(L("Invalid certificate")) }
            let dir = Paths.certificates.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try der.write(to: dir.appendingPathComponent("cert.der"))
            AppleAccount.saveSession(s, for: id)
            Keychain.set(password, for: "appleid.password." + id.uuidString)
            let pd = ProfileDetails(name: "Apple ID: " + s.email, teamName: team["name"] as? String ?? "", teamID: teamID,
                                    appID: teamID + ".*", expiration: details.notAfter, creation: Date(),
                                    devices: [state.settings.udid], allDevices: false, getTaskAllow: true,
                                    entitlementKeys: ["application-identifier", "get-task-allow", "keychain-access-groups"])
            let cert = StoredCertificate(id: id, nickname: s.email, details: details, profile: pd, p12File: "",
                                         profileFile: "", added: Date(), ocsp: .unchecked, ocspChecked: nil,
                                         revokedAt: nil, fromAppleID: true)
            state.certificates.append(cert)
            state.settings.selectedCertificate = id
            state.settings.appleIDTeam = teamID
            state.save()
            state.show(L("Apple ID certificate is ready"))
            Haptics.success()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Apple ID account

struct AppleAccountView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    let cert: StoredCertificate
    @State private var api: DeveloperAPI?
    @State private var certs: [[String: Any]] = []
    @State private var devices: [[String: Any]] = []
    @State private var loading = false
    @State private var error: String?
    @State private var newName = ""
    @State private var newUDID = ""
    @State private var revokeSerial: String?
    @State private var removeDevice: [String: Any]?

    var team: String { cert.profile.teamID }

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground(accent: Theme.lilac)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topBar
                        accountHeader
                        if let e = error { BannerView(kind: .error, text: e) }
                        certificatesPanel
                        devicesPanel
                        addDevicePanel
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .confirmationDialog(L("Revoke this certificate?"), isPresented: Binding(get: { revokeSerial != nil }, set: { if !$0 { revokeSerial = nil } }),
                                titleVisibility: .visible) {
                Button(L("Revoke"), role: .destructive) {
                    let s = revokeSerial
                    revokeSerial = nil
                    if let s = s { Task { await revoke(s) } }
                }
            } message: {
                Text(isMine(revokeSerial ?? "") ? L("SayoSign signs with this certificate. After revoking, sign in to your Apple ID again.") : L("Apps signed with it will stop opening."))
            }
            .confirmationDialog(L("Remove this device?"), isPresented: Binding(get: { removeDevice != nil }, set: { if !$0 { removeDevice = nil } }),
                                titleVisibility: .visible) {
                Button(L("Remove"), role: .destructive) {
                    let d = removeDevice
                    removeDevice = nil
                    if let d = d { Task { await remove(d) } }
                }
            }
            .task { await reload() }
        }
        .navigationViewStyle(.stack)
    }

    private var topBar: some View {
        HStack {
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
            .accessibilityLabel(L("Close"))
            .accessibilityIdentifier("appleaccount.close")
            Spacer()
            Text(L("Apple ID account"))
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button {
                Haptics.light()
                Task { await reload() }
            } label: {
                if loading {
                    ProgressView().scaleEffect(0.8).frame(width: 40, height: 40)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 0.7)))
                }
            }
            .disabled(loading)
            .accessibilityLabel(L("Refresh"))
        }
    }

    private var accountHeader: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.inkGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: "applelogo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(cert.nickname)
                    .font(SayoType.title3)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(cert.profile.teamName)
                    .font(SayoType.caption)
                    .foregroundColor(Theme.textSecondary)
                Text("Team ID " + team)
                    .font(SayoType.monoSmall)
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(14)
        .background(panel)
    }

    private var certificatesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Certificates"),
                         subtitle: L("Free accounts can have only two development certificates. A revoked certificate stops working for every app signed with it."))
            VStack(spacing: 0) {
                if certs.isEmpty && !loading {
                    Text(L("No certificates"))
                        .font(SayoType.caption)
                        .foregroundColor(Theme.textTertiary)
                        .padding(.vertical, 8)
                }
                ForEach(certs.indices, id: \.self) { i in
                    let c = certs[i]
                    let serial = c["serialNumber"] as? String ?? ""
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c["machineName"] as? String ?? c["name"] as? String ?? L("Certificate"))
                                .font(SayoType.bodyStrong)
                                .foregroundColor(Theme.textPrimary)
                            Text(serial)
                                .font(SayoType.monoSmall)
                                .foregroundColor(Theme.textTertiary)
                                .textSelection(.enabled)
                            if let d = c["expirationDate"] as? Date {
                                Text(LF("Expires %@", dateFormatter.string(from: d)))
                                    .font(SayoType.micro)
                                    .foregroundColor(Theme.textTertiary)
                            }
                            if isMine(serial) {
                                Pill(text: L("Used by this SayoSign certificate"), color: Theme.coral)
                            }
                        }
                        Spacer(minLength: 6)
                        Button(role: .destructive) {
                            revokeSerial = serial
                        } label: {
                            Text(L("Revoke"))
                        }
                        .buttonStyle(SmallButtonStyle(filled: false))
                        .disabled(loading || serial.isEmpty)
                    }
                    .padding(.vertical, 10)
                    if i < certs.count - 1 { DividerSoft() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(panel)
        }
    }

    private var devicesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Devices"),
                         subtitle: L("Apps signed with this account install only on these devices."))
            VStack(spacing: 0) {
                if devices.isEmpty && !loading {
                    Text(L("No devices"))
                        .font(SayoType.caption)
                        .foregroundColor(Theme.textTertiary)
                        .padding(.vertical, 8)
                }
                ForEach(devices.indices, id: \.self) { i in
                    let d = devices[i]
                    let udid = d["deviceNumber"] as? String ?? ""
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(d["name"] as? String ?? "iPhone")
                                .font(SayoType.bodyStrong)
                                .foregroundColor(Theme.textPrimary)
                            Text(udid)
                                .font(SayoType.monoSmall)
                                .foregroundColor(Theme.textTertiary)
                                .textSelection(.enabled)
                            if udid.uppercased() == state.settings.udid.uppercased() && !udid.isEmpty {
                                Pill(text: L("This iPhone"), color: Theme.coral)
                            }
                        }
                        Spacer(minLength: 6)
                        Button(role: .destructive) { removeDevice = d } label: {
                            Text(L("Remove"))
                        }
                        .buttonStyle(SmallButtonStyle(filled: false))
                        .disabled(loading)
                    }
                    .padding(.vertical, 10)
                    if i < devices.count - 1 { DividerSoft() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(panel)
        }
    }

    private var addDevicePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Add device"))
            SayoTextField(title: L("Name"), placeholder: "iPhone", text: $newName)
            SayoTextField(title: "UDID", placeholder: "00008110-000000000000001E", text: $newUDID,
                          capitalization: .characters, mono: true)
            Button {
                Haptics.medium()
                Task { await addDevice() }
            } label: {
                HStack(spacing: 7) {
                    if loading { ProgressView().tint(.white).scaleEffect(0.8) }
                    Text(L("Add"))
                }
            }
            .buttonStyle(SmallButtonStyle())
            .disabled(loading || newUDID.trimmingCharacters(in: .whitespaces).count < 20)
        }
        .padding(15)
        .background(panel)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
    }

    // MARK: - Logic (unchanged)

    func isMine(_ serial: String) -> Bool { sameSerial(serial, cert.details.serial) }

    func connect() async throws -> DeveloperAPI {
        if let a = api { return a }
        guard let s = AppleAccount.session(for: cert.id) else { throw SayoError(L("Sign in to your Apple ID again")) }
        if s.expiry < Date() { throw SayoError(L("Your Apple ID session expired, sign in again")) }
        let ani = try await Anisette.fetch(s.anisette ?? state.settings.anisetteURL)
        let a = DeveloperAPI(session: s, anisette: ani)
        api = a
        return a
    }

    func run(_ work: (DeveloperAPI) async throws -> Void) async {
        loading = true
        error = nil
        defer { loading = false }
        do { try await work(try await connect()) } catch { self.error = error.localizedDescription }
    }

    func reload() async {
        await run { a in
            certs = try await a.call("listAllDevelopmentCerts", ["teamId": team])["certificates"] as? [[String: Any]] ?? []
            devices = try await a.call("listDevices", ["teamId": team])["devices"] as? [[String: Any]] ?? []
        }
    }

    func revoke(_ serial: String) async {
        await run { a in
            _ = try await a.call("revokeDevelopmentCert", ["teamId": team, "serialNumber": serial])
            state.show(L("Certificate revoked"))
        }
        await reload()
    }

    func remove(_ d: [String: Any]) async {
        guard let id = d["deviceId"] as? String else { error = L("Apple did not send this device's ID"); return }
        await run { a in
            _ = try await a.call("deleteDevice", ["teamId": team, "deviceId": id])
            state.show(L("Device removed"))
        }
        await reload()
    }

    func addDevice() async {
        let udid = newUDID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let name = newName.trimmingCharacters(in: .whitespaces)
        await run { a in
            _ = try await a.call("addDevice", ["teamId": team, "deviceNumber": udid, "name": name.isEmpty ? "iPhone" : name])
            state.show(L("Device added"))
            newUDID = ""
            newName = ""
        }
        await reload()
    }
}
