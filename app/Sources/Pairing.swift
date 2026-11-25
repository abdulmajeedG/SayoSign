import Foundation
import SwiftUI
import UIKit

/// iOS 27 on-device pairing and installs through the pairing tunnel (rust/sayoidev, built on
/// idevice). This is SideStore's install path: it works for free Apple ID profiles, which
/// over-the-air installs refuse. Needs LocalDevVPN (or another loopback VPN) connected.
enum DeviceLink {
    static var pairingFile: URL { Paths.support.appendingPathComponent("rp_pairing_file.plist") }
    static var isPaired: Bool { FileManager.default.fileExists(atPath: pairingFile.path) }
    static let hostName = "SayoSign"

    /// Saves an RPPairing file made elsewhere (StikDebug, PhonePair, idevice_pair).
    static func importPairing(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard let p = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw SayoError(L("This is not a pairing file"))
        }
        // Lockdown pairing files (.mobiledevicepairing) carry HostCertificate; RPPairing ones do not.
        if p["HostCertificate"] != nil && p["public_key"] == nil && p["publicKey"] == nil {
            throw SayoError(L("This is a lockdown pairing file. SayoSign needs an RPPairing file (iOS 27 pairing)."))
        }
        try? FileManager.default.removeItem(at: pairingFile)
        try data.write(to: pairingFile, options: .completeFileProtectionUntilFirstUserAuthentication)
    }

    static func forget() { try? FileManager.default.removeItem(at: pairingFile) }

    static func check(address: String, port: Int) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            var out = [CChar](repeating: 0, count: 256)
            var err = [CChar](repeating: 0, count: 512)
            let rc = sayo_idev_check(DeviceLink.pairingFile.path, address, UInt16(clamping: port), &out, out.count, &err, err.count)
            if rc != 0 { throw SayoError(String(cString: err)) }
            return String(cString: out)
        }.value
    }

    final class ProgressBox {
        let fn: (Int, String) -> Void
        init(_ fn: @escaping (Int, String) -> Void) { self.fn = fn }
    }

    /// Uploads and installs the IPA through the tunnel; `progress` gets (percent, stage).
    static func install(ipa: URL, address: String, port: Int, progress: @escaping (Int, String) -> Void) async throws {
        guard isPaired else { throw SayoError(L("Pair this iPhone first: Settings → Installing → Pair this iPhone")) }
        let box = ProgressBox(progress)
        try await Task.detached(priority: .userInitiated) {
            let ctx = Unmanaged.passRetained(box).toOpaque()
            defer { Unmanaged<ProgressBox>.fromOpaque(ctx).release() }
            var err = [CChar](repeating: 0, count: 512)
            let cb: sayo_idev_progress_cb = { pct, stage, ctx in
                guard let ctx = ctx else { return }
                let b = Unmanaged<ProgressBox>.fromOpaque(ctx).takeUnretainedValue()
                let s = stage.map { String(cString: $0) } ?? ""
                DispatchQueue.main.async { b.fn(Int(pct), s) }
            }
            let rc = sayo_idev_install(DeviceLink.pairingFile.path, address, UInt16(clamping: port), ipa.path, cb, ctx, &err, err.count)
            if rc != 0 { throw SayoError(String(cString: err)) }
        }.value
    }
}

/// Runs the pairable host: advertises SayoSign over Bonjour and waits for the user to tap
/// "Pair with SayoSign" in Settings → Privacy & Security → Developer Mode.
final class PairingHost: NSObject, ObservableObject, NetServiceDelegate {
    @Published var pin: String?
    @Published var state = ""
    @Published var running = false
    @Published var error: String?
    @Published var done = false
    private var service: NetService?
    private var cancel: OpaquePointer?

    func start() {
        guard !running else { return }
        running = true
        error = nil
        pin = nil
        done = false
        state = L("Waiting for the iPhone…")
        // The user goes to Settings while pairing: keep SayoSign running in the background
        // and be allowed to show the PIN there as a notification.
        InstallServer.shared.keepAlive(true)
        let token = sayo_idev_cancel_new()
        cancel = token
        let ctx = Unmanaged.passRetained(self).toOpaque()
        let out = DeviceLink.pairingFile.path + ".new"
        Thread.detachNewThread { [weak self] in
            var err = [CChar](repeating: 0, count: 512)
            let ready: sayo_idev_ready_cb = { port, json, ctx in
                guard let ctx = ctx, let json = json else { return }
                let me = Unmanaged<PairingHost>.fromOpaque(ctx).takeUnretainedValue()
                let text = String(cString: json)
                DispatchQueue.main.async { me.advertise(port: Int(port), json: text) }
            }
            let pinCb: sayo_idev_pin_cb = { pin, ctx in
                guard let ctx = ctx, let pin = pin else { return }
                let me = Unmanaged<PairingHost>.fromOpaque(ctx).takeUnretainedValue()
                let p = String(cString: pin)
                DispatchQueue.main.async {
                    me.pin = p
                    me.state = L("Type this code on the iPhone")
                }
            }
            let rc = sayo_idev_pair_host(DeviceLink.hostName, nil, out, ready, pinCb, ctx, token, &err, err.count)
            let message = String(cString: err)
            DispatchQueue.main.async {
                Unmanaged<PairingHost>.fromOpaque(ctx).release()
                guard let self = self else { return }
                self.service?.stop()
                self.service = nil
                InstallServer.shared.keepAlive(false)
                sayo_idev_cancel_free(token)
                self.cancel = nil
                self.running = false
                if rc == 0 {
                    try? FileManager.default.removeItem(at: DeviceLink.pairingFile)
                    try? FileManager.default.moveItem(atPath: out, toPath: DeviceLink.pairingFile.path)
                    self.done = true
                    self.state = L("Paired")
                } else if rc == -2 {
                    self.state = ""
                } else {
                    self.error = message.isEmpty ? L("Pairing failed") : message
                    self.state = ""
                }
            }
        }
    }

    func stop() {
        if let c = cancel { sayo_idev_cancel_signal(c) }
        service?.stop()
    }

    private func advertise(port: Int, json: String) {
        guard let d = json.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let name = o["name"] as? String else { return }
        let txt = (o["txt"] as? [String: String] ?? [:]).mapValues { Data($0.utf8) }
        let s = NetService(domain: "local.", type: "_remotepairing-pairable-host._tcp.", name: name, port: Int32(port))
        s.setTXTRecord(NetService.data(fromTXTRecord: txt))
        s.delegate = self
        s.publish()
        service = s
        state = L("Open Settings → Privacy & Security → Developer Mode and tap Pair with SayoSign")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let code = errorDict[NetService.errorCode]?.intValue ?? 0
        error = L("Could not advertise on the local network. Connect to Wi-Fi, allow Local Network for SayoSign (Settings → Privacy & Security → Local Network) and try again.")
            + " (\(code))"
        stop()
    }
}


// MARK: - Pairing UI (PairingHost and install logic live above)

struct PairingView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var host = PairingHost()
    @State private var importing = false
    @State private var checking = false
    @State private var checkResult: String?
    @State private var paired = DeviceLink.isPaired

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground(accent: Theme.mint)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topBar
                        hero
                        pairingPanel
                        importPanel
                        if paired { connectionPanel }
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: host.done) { d in
                if d {
                    paired = true
                    state.show(L("This iPhone is paired"))
                    Haptics.success()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.light()
                host.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 0.7)))
            }
            .accessibilityLabel(L("Close"))
            .accessibilityIdentifier("pair.close")
            Spacer()
            Text(L("Pairing"))
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            BrandMark(size: 34)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(paired ? Theme.success.opacity(0.11) : Theme.mint.opacity(0.11))
                    .frame(width: 90, height: 90)
                Circle()
                    .stroke(paired ? Theme.success.opacity(0.18) : Theme.mint.opacity(0.16), lineWidth: 1)
                    .frame(width: 68, height: 68)
                Image(systemName: paired ? "checkmark.seal.fill" : "link.badge.plus")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(paired ? Theme.success : Theme.mint)
            }
            VStack(spacing: 4) {
                Text(paired ? L("This iPhone is paired") : L("Not paired yet"))
                    .font(SayoType.title)
                    .foregroundColor(Theme.textPrimary)
                Text(L("Pairing lets SayoSign install apps the way SideStore does, including apps signed with a free Apple ID. It needs iOS 27, Developer Mode and LocalDevVPN (free on the App Store) connected while installing."))
                    .font(SayoType.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.top, 6)
    }

    private var pairingPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(title: L("Pair on this iPhone (iOS 27)"))
            VStack(spacing: 13) {
                if host.running {
                    if let p = host.pin {
                        VStack(spacing: 7) {
                            Text(p)
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .tracking(6)
                                .foregroundColor(Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .textSelection(.enabled)
                            Text(host.state)
                                .font(SayoType.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(Theme.surfaceInset.opacity(0.55))
                        )
                        HStack(spacing: 9) {
                            Button {
                                UIPasteboard.general.string = p
                                state.show(L("Code copied"))
                                Haptics.selection()
                            } label: {
                                Label(L("Copy code"), systemImage: "doc.on.doc")
                            }
                            .buttonStyle(SmallButtonStyle(filled: false))
                            Button {
                                Haptics.light()
                                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                            } label: {
                                Label(L("Open Settings"), systemImage: "gear")
                            }
                            .buttonStyle(SmallButtonStyle())
                        }
                    } else {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(host.state)
                                .font(SayoType.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(role: .destructive) {
                        Haptics.warning()
                        host.stop()
                    } label: {
                        Text(L("Cancel"))
                            .font(SayoType.captionStrong)
                            .foregroundColor(Theme.danger)
                    }
                } else {
                    Button {
                        Haptics.medium()
                        host.start()
                    } label: {
                        Label(L("Pair this iPhone"), systemImage: "iphone.and.arrow.forward")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text(L("Tap Pair, then open Settings → Privacy & Security → Developer Mode → Pair with SayoSign and type the code shown here."))
                        .font(SayoType.micro)
                        .foregroundColor(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let e = host.error {
                    BannerView(kind: .error, text: e)
                }
            }
            .padding(15)
            .background(panel)
        }
    }

    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Or import a pairing file"),
                         subtitle: L("An RPPairing file from StikDebug or PhonePair works too."))
            Button { pick() } label: {
                HStack(spacing: 12) {
                    IconBadge(symbol: "doc.badge.plus", tint: Theme.lilac, size: 34)
                    Text(L("Import pairing file"))
                        .font(SayoType.bodyStrong)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Theme.coral)
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel(title: L("Connection"), subtitle: L("Turn LocalDevVPN on, then check."))
            VStack(alignment: .leading, spacing: 11) {
                SayoTextField(title: L("Address"), placeholder: "10.7.0.1", text: $state.settings.tunnelAddress,
                              keyboard: .numbersAndPunctuation, capitalization: .never)
                Button {
                    Haptics.light()
                    Task { await check() }
                } label: {
                    HStack(spacing: 8) {
                        Label(L("Check connection"), systemImage: "bolt.horizontal")
                        Spacer()
                        if checking { ProgressView().scaleEffect(0.8) }
                    }
                    .font(SayoType.captionStrong)
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.surfaceInset.opacity(0.55)))
                }
                .buttonStyle(.plain)
                .disabled(checking)
                if let r = checkResult {
                    Text(r)
                        .font(SayoType.caption)
                        .foregroundColor(r.hasPrefix("✓") ? Theme.success : Theme.danger)
                }
                if let u = URL(string: "https://apps.apple.com/search?term=LocalDevVPN") {
                    Link(destination: u) {
                        HStack(spacing: 8) {
                            IconBadge(symbol: "lock.shield.fill", tint: Theme.info, size: 32)
                            Text(L("Get LocalDevVPN"))
                                .font(SayoType.bodyStrong)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                DividerSoft()
                Button(role: .destructive) {
                    Haptics.warning()
                    DeviceLink.forget()
                    paired = false
                    checkResult = nil
                } label: {
                    Label(L("Forget pairing"), systemImage: "trash")
                        .font(SayoType.captionStrong)
                        .foregroundColor(Theme.danger)
                }
                .padding(.vertical, 5)
            }
            .padding(15)
            .background(panel)
        }
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
    }

    // MARK: - Logic (unchanged)

    func pick() {
        FilePicker.shared.pick([.item], multiple: false) { urls in
            guard let u = urls.first else { return }
            do {
                try DeviceLink.importPairing(u)
                try? FileManager.default.removeItem(at: u)
                paired = true
                state.show(L("Pairing file imported"))
                Haptics.success()
            } catch {
                host.error = error.localizedDescription
                Haptics.error()
            }
        }
    }

    func check() async {
        checking = true
        defer { checking = false }
        do {
            checkResult = "✓ " + (try await DeviceLink.check(address: state.settings.tunnelAddress, port: 49152))
            Haptics.success()
        } catch {
            checkResult = "✗ " + error.localizedDescription
            Haptics.error()
        }
    }
}
