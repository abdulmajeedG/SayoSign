import Foundation
import Security
import SwiftUI
import UIKit

enum Crypto {
    static func sha256(_ d: Data) -> Data {
        var out = [UInt8](repeating: 0, count: 32)
        d.withUnsafeBytes { sayo_sha256($0.baseAddress, d.count, &out) }
        return Data(out)
    }

    static func hmac(_ key: Data, _ msg: Data) -> Data {
        var out = [UInt8](repeating: 0, count: 32)
        key.withUnsafeBytes { k in
            msg.withUnsafeBytes { m in
                sayo_hmac_sha256(k.bindMemory(to: UInt8.self).baseAddress, key.count, m.bindMemory(to: UInt8.self).baseAddress, msg.count, &out)
            }
        }
        return Data(out)
    }

    static func pbkdf2(_ pw: Data, salt: Data, iterations: Int) -> Data {
        var out = [UInt8](repeating: 0, count: 32)
        pw.withUnsafeBytes { p in
            salt.withUnsafeBytes { s in
                sayo_pbkdf2_sha256(p.bindMemory(to: UInt8.self).baseAddress, pw.count, s.bindMemory(to: UInt8.self).baseAddress, salt.count, UInt32(iterations), &out, 32)
            }
        }
        return Data(out)
    }

    static func cbcDecrypt(key: Data, iv: Data, _ data: Data) throws -> Data {
        var out = sayo_buf()
        let ivb = [UInt8](iv.prefix(16))
        let rc = key.withUnsafeBytes { k in
            data.withUnsafeBytes { d in
                sayo_aes_cbc_decrypt(k.bindMemory(to: UInt8.self).baseAddress, key.count, ivb, d.bindMemory(to: UInt8.self).baseAddress, data.count, &out)
            }
        }
        defer { sayo_buf_free(&out) }
        guard rc == 0, let p = out.data else { throw SayoError.last("Decryption failed") }
        return Data(bytes: p, count: out.len)
    }

    static func gcmDecrypt(key: Data, _ blob: Data) throws -> Data {
        guard blob.count > 3 + 16 + 16 else { throw SayoError("Encrypted token is too short") }
        let b = [UInt8](blob)
        let aad = Array(b[0..<3])
        let iv = Array(b[3..<19])
        let tag = Array(b[(b.count - 16)...])
        let ct = Array(b[19..<(b.count - 16)])
        var out = sayo_buf()
        let rc = key.withUnsafeBytes { k in
            sayo_aes_gcm_decrypt(k.bindMemory(to: UInt8.self).baseAddress, key.count, iv, 16, aad, 3, ct, ct.count, tag, &out)
        }
        defer { sayo_buf_free(&out) }
        guard rc == 0, let p = out.data else { throw SayoError.last("Token decryption failed") }
        return Data(bytes: p, count: out.len)
    }

    static func random(_ n: Int) -> Data {
        var d = Data(count: n)
        _ = d.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, n, $0.baseAddress!) }
        return d
    }
}

/// Anisette client: the v3 protocol (provisioning over WebSocket + /v3/get_headers) with a
/// v1 fallback (GET / returning JSON). Since October 2026 Apple rejects anisette that does not
/// match the client info it was made for, so every Apple request uses the client info and the
/// user agent that the anisette server reports at /v3/client_info.
final class Anisette {
    /// Mac-based servers: Apple accepts these. Android-based ones fail with -80045 or HTTP 401.
    static let presets: [(name: String, url: String)] = [
        ("iloader", "https://ani.iloader.app"),
        ("jkcoxson (Mac)", "https://mac-ani.jkcoxson.com"),
        ("SideStore (new)", "https://new.ani.sidestore.io"),
    ]
    static let defaultServer = "https://ani.iloader.app"
    /// Servers that Apple now rejects; settings pointing here are migrated to the default.
    static let rejectedServers: Set<String> = ["https://ani.sidestore.io", "https://ani.sidestore.zip",
                                               "http://ani.sidestore.io", "https://ani.sidestore.io/"]
    static let xcodeVersion = "27.0 (27A5218g)"
    static let lookupURL = URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!

    let server: String
    private(set) var version = "v3"
    private(set) var clientInfo = ""
    private(set) var userAgent = ""
    private(set) var headers: [String: String] = [:]
    private(set) var bag: [String: String] = [:]
    private var fetchedAt = Date.distantPast
    private var identifier: Data
    private var adiPB: Data?

    init(server raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        if !s.isEmpty && !s.contains("://") { s = "https://" + s }
        server = s
        identifier = Crypto.random(16)
        loadState()
    }

    static func fetch(_ server: String) async throws -> Anisette {
        guard URL(string: server.isEmpty ? defaultServer : server) != nil else { throw SayoError(L("Invalid anisette server")) }
        let a = Anisette(server: server.isEmpty ? defaultServer : server)
        try await a.detect()
        try await a.loadBag()
        try await a.refresh()
        return a
    }

    // MARK: identity (persisted per server so we provision only once)

    private var stateKey: String { "anisette.v3." + Crypto.sha256(Data(server.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined() }

    private func loadState() {
        guard let s = Keychain.get(stateKey), let d = s.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: String],
              let id = o["identifier"].flatMap({ Data(base64Encoded: $0) }), id.count == 16 else { return }
        identifier = id
        adiPB = o["adi_pb"].flatMap { Data(base64Encoded: $0) }
    }

    private func saveState() {
        var o = ["identifier": identifier.base64EncodedString()]
        if let p = adiPB { o["adi_pb"] = p.base64EncodedString() }
        if let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) {
            Keychain.set(s, for: stateKey)
        }
    }

    func reset() {
        identifier = Crypto.random(16)
        adiPB = nil
        fetchedAt = .distantPast
        saveState()
    }

    var deviceID: String {
        let b = [UInt8](identifier)
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])).uuidString.lowercased()
    }
    var localUserID: String { Crypto.sha256(identifier).map { String(format: "%02x", $0) }.joined() }
    var isProvisioned: Bool { version == "v1" || adiPB != nil }
    var isMacClient: Bool { clientInfo.contains("Mac OS X") || clientInfo.contains("macOS") }
    var isLegacyClient: Bool { clientInfo.contains("3594.4.19") }

    // MARK: discovery

    private func getJSON(_ path: String, body: [String: Any]? = nil, timeout: TimeInterval = 20) async throws -> [String: Any] {
        guard let url = URL(string: server + path) else { throw SayoError(L("Invalid anisette server")) }
        var r = URLRequest(url: url)
        r.timeoutInterval = timeout
        if let b = body {
            r.httpMethod = "POST"
            r.httpBody = try JSONSerialization.data(withJSONObject: b)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, _) = try await URLSession.shared.data(for: r)
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SayoError(L("This is not an anisette server, or it is down."))
        }
        return o
    }

    func detect() async throws {
        if let o = try? await getJSON("/v3/client_info", timeout: 12),
           let ci = o["client_info"] as? String, let ua = o["user_agent"] as? String {
            version = "v3"
            clientInfo = ci
            userAgent = ua
            return
        }
        let o = try await getJSON("/")
        guard o["X-Apple-I-MD"] != nil, o["X-Apple-I-MD-M"] != nil else {
            throw SayoError(L("The anisette server response is missing machine data"))
        }
        version = "v1"
        clientInfo = (o["X-MMe-Client-Info"] as? String) ?? "<MacBookPro13,3> <Mac OS X;10.12.6;16G29> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
        userAgent = "akd/1.0 CFNetwork/811.5.4 Darwin/16.7.0"
    }

    // MARK: Apple

    func applyBase(_ r: inout URLRequest, json: Bool = false) {
        let ct = json ? "application/json" : "text/x-xml-plist"
        r.setValue(ct, forHTTPHeaderField: "Content-Type")
        r.setValue(ct, forHTTPHeaderField: "Accept")
        r.setValue(clientInfo, forHTTPHeaderField: "X-Mme-Client-Info")
        r.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        r.setValue(Anisette.xcodeVersion, forHTTPHeaderField: "X-Xcode-Version")
        r.setValue("com.apple.gs.xcode.auth", forHTTPHeaderField: "X-Apple-App-Info")
    }

    func loadBag() async throws {
        var r = URLRequest(url: Anisette.lookupURL)
        applyBase(&r)
        let (data, resp) = try await URLSession.shared.data(for: r)
        if let h = resp as? HTTPURLResponse, h.statusCode == 401 {
            throw SayoError(L("Apple rejected this anisette server. Choose a Mac-based server like ani.iloader.app."))
        }
        guard let p = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let urls = p["urls"] as? [String: Any] else { throw SayoError(L("Unexpected response from Apple")) }
        bag = urls.compactMapValues { $0 as? String }
    }

    func url(_ key: String) throws -> URL {
        guard let s = bag[key], let u = URL(string: s) else { throw SayoError(L("Unexpected response from Apple") + " (\(key))") }
        return u
    }

    private func applePlist(_ url: URL, _ request: [String: Any]) async throws -> [String: Any] {
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        applyBase(&r)
        r.setValue(localUserID, forHTTPHeaderField: "X-Apple-I-MD-LU")
        r.setValue(deviceID, forHTTPHeaderField: "X-Mme-Device-Id")
        r.setValue(Anisette.clientTime(), forHTTPHeaderField: "X-Apple-I-Client-Time")
        r.setValue("UTC", forHTTPHeaderField: "X-Apple-I-TimeZone")
        r.setValue("en_US", forHTTPHeaderField: "X-Apple-Locale")
        r.httpBody = try PropertyListSerialization.data(fromPropertyList: ["Header": [String: Any](), "Request": request], format: .xml, options: 0)
        let (data, resp) = try await URLSession.shared.data(for: r)
        if let h = resp as? HTTPURLResponse, h.statusCode == 401 {
            throw SayoError(L("Apple rejected this anisette server. Choose a Mac-based server like ani.iloader.app."))
        }
        guard let p = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let out = p["Response"] as? [String: Any] else { throw SayoError(L("Unexpected response from Apple")) }
        return out
    }

    // MARK: v3 provisioning

    private func provision() async throws {
        let start = try url("midStartProvisioning"), finish = try url("midFinishProvisioning")
        let wsString = server.replacingOccurrences(of: "https://", with: "wss://").replacingOccurrences(of: "http://", with: "ws://")
        guard let wsURL = URL(string: wsString + "/v3/provisioning_session") else { throw SayoError(L("Invalid anisette server")) }
        let task = URLSession.shared.webSocketTask(with: wsURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }
        func send(_ o: [String: String]) async throws {
            let d = try JSONSerialization.data(withJSONObject: o)
            try await task.send(.string(String(data: d, encoding: .utf8) ?? "{}"))
        }
        for _ in 0..<12 {
            let msg = try await task.receive()
            let text: String
            switch msg {
            case .string(let s): text = s
            case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
            @unknown default: text = ""
            }
            guard let m = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { continue }
            switch m["result"] as? String ?? "" {
            case "GiveIdentifier":
                try await send(["identifier": identifier.base64EncodedString()])
            case "GiveStartProvisioningData":
                let r = try await applePlist(start, [:])
                guard let spim = r["spim"] as? String else { throw SayoError(L("Unexpected response from Apple")) }
                try await send(["spim": spim])
            case "GiveEndProvisioningData":
                let r = try await applePlist(finish, ["cpim": m["cpim"] as? String ?? ""])
                guard let ptm = r["ptm"] as? String, let tk = r["tk"] as? String else { throw SayoError(L("Unexpected response from Apple")) }
                try await send(["ptm": ptm, "tk": tk])
            case "ProvisioningSuccess":
                guard let s = m["adi_pb"] as? String, let d = Data(base64Encoded: s) else { throw SayoError(L("Anisette provisioning failed")) }
                adiPB = d
                saveState()
                return
            case let other:
                let detail = (m["message"] as? String).map { ": " + $0 } ?? ""
                throw SayoError(L("Anisette provisioning failed") + " (\(other)\(detail))")
            }
        }
        throw SayoError(L("Anisette provisioning failed"))
    }

    // MARK: headers

    static func clientTime() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    func refresh() async throws {
        var h: [String: String] = [:]
        if version == "v1" {
            let o = try await getJSON("/")
            for (k, v) in o { if let s = v as? String { h[k] = s } else if let n = v as? NSNumber { h[k] = n.stringValue } }
            h["X-Apple-I-MD-LU"] = h["X-Apple-I-MD-LU"] ?? localUserID
            h["X-Mme-Device-Id"] = h["X-Mme-Device-Id"] ?? deviceID
        } else {
            var got: [String: Any]?
            for attempt in 0..<2 {
                if adiPB == nil { try await provision() }
                let o = try await getJSON("/v3/get_headers", body: ["identifier": identifier.base64EncodedString(),
                                                                     "adi_pb": adiPB?.base64EncodedString() ?? ""])
                if o["result"] as? String == "Headers" { got = o; break }
                if attempt == 0 { reset(); continue }
                throw SayoError(L("Anisette server error") + ": " + (o["message"] as? String ?? ""))
            }
            guard let o = got else { throw SayoError(L("Anisette server error")) }
            h["X-Apple-I-MD"] = o["X-Apple-I-MD"] as? String
            h["X-Apple-I-MD-M"] = o["X-Apple-I-MD-M"] as? String
            h["X-Apple-I-MD-RINFO"] = (o["X-Apple-I-MD-RINFO"] as? String) ?? (o["X-Apple-I-MD-RINFO"] as? NSNumber)?.stringValue ?? "17106176"
            h["X-Apple-I-MD-LU"] = localUserID
            h["X-Mme-Device-Id"] = deviceID
        }
        guard h["X-Apple-I-MD"] != nil, h["X-Apple-I-MD-M"] != nil else {
            throw SayoError(L("The anisette server response is missing machine data"))
        }
        h["X-Apple-I-SRL-NO"] = "0"
        h["X-Apple-I-Client-Time"] = Anisette.clientTime()
        h["X-Apple-I-TimeZone"] = "UTC"
        h["X-Apple-Locale"] = "en_US"
        headers = h
        fetchedAt = Date()
    }

    /// One-time passwords live about a minute; refresh before a request if needed.
    func fresh() async throws {
        if Date().timeIntervalSince(fetchedAt) > 40 { try await refresh() }
    }

    private static let anisetteKeys = ["X-Apple-I-Client-Time", "X-Apple-I-MD", "X-Apple-I-MD-M", "X-Apple-I-MD-LU",
                                       "X-Apple-I-MD-RINFO", "X-Apple-I-SRL-NO", "X-Apple-I-TimeZone", "X-Apple-Locale", "X-Mme-Device-Id"]

    var cpd: [String: Any] {
        var d: [String: Any] = ["bootstrap": true, "icscrec": true, "pbe": false, "prkgen": true, "svct": "iCloud", "loc": "en_US"]
        for k in Anisette.anisetteKeys { if let v = headers[k] { d[k] = v } }
        return d
    }

    /// Base headers plus the anisette headers, for 2FA and developer requests.
    func apply(_ r: inout URLRequest, json: Bool = false) {
        applyBase(&r, json: json)
        for k in Anisette.anisetteKeys { if let v = headers[k] { r.setValue(v, forHTTPHeaderField: k) } }
        r.setValue("en_US", forHTTPHeaderField: "Loc")
    }
}

/// Friendly text for common GrandSlam error codes.
func grandSlamError(_ status: [String: Any]) -> SayoError? {
    let ec = (status["ec"] as? Int) ?? 0
    if ec == 0 { return nil }
    let known: [Int: String] = [
        -20101: L("Wrong Apple ID or password"), -22406: L("Wrong Apple ID or password"),
        -20209: L("This Apple ID is locked. Unlock it at iforgot.apple.com"), -20751: L("This Apple ID is locked. Unlock it at iforgot.apple.com"),
        -80045: L("Apple rejected the anisette data. Choose a Mac-based anisette server and reset anisette."),
        -80046: L("Apple rejected the anisette data. Choose a Mac-based anisette server and reset anisette."),
        -45061: L("Anisette is not provisioned for this server. Reset anisette and try again."),
        -22410: L("Too many attempts. Wait a few minutes and try again."),
        -22411: L("Apple is limiting sign-ins right now. Try again later."),
        -21669: L("Wrong code"),
        -22421: L("Wrong code"),
    ]
    let msg = known[ec] ?? (status["em"] as? String) ?? L("Unexpected response from Apple")
    return SayoError("\(msg) (\(ec))")
}

struct AppleSession: Codable {
    var adsid: String
    var idmsToken: String
    var xcodeToken: String
    var expiry: Date
    var email: String
}

enum SecondFactor {
    case trustedDevice
    case sms
}

final class GSAuth {
    let anisette: Anisette
    let email: String
    let password: String

    init(anisette: Anisette, email: String, password: String) {
        self.anisette = anisette
        self.email = email
        self.password = password
    }

    private func post(_ body: [String: Any]) async throws -> [String: Any] {
        try await anisette.fresh()
        var request = body
        request["cpd"] = anisette.cpd
        let wrapped: [String: Any] = ["Header": ["Version": "1.0.1"], "Request": request]
        var r = URLRequest(url: try anisette.url("gsService"))
        r.httpMethod = "POST"
        r.httpBody = try PropertyListSerialization.data(fromPropertyList: wrapped, format: .xml, options: 0)
        anisette.applyBase(&r)
        r.setValue("close", forHTTPHeaderField: "Connection")
        let (data, resp) = try await URLSession.shared.data(for: r)
        if let h = resp as? HTTPURLResponse, [500, 503].contains(h.statusCode) {
            throw SayoError(L("Apple rejected the anisette data. Choose a Mac-based anisette server and reset anisette.") + " (HTTP \(h.statusCode))")
        }
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let resp = plist["Response"] as? [String: Any] else { throw SayoError(L("Unexpected response from Apple")) }
        if let st = resp["Status"] as? [String: Any], let err = grandSlamError(st) { throw err }
        return resp
    }

    struct LoginResult {
        var adsid: String
        var idmsToken: String
        var sk: Data
        var c: Data
        var needs2FA: SecondFactor?
    }

    func login() async throws -> LoginResult {
        var srp = sayo_srp()
        var A = Data()
        repeat {
            let rnd = [UInt8](Crypto.random(32))
            sayo_srp_init(&srp, rnd)
            A = withUnsafeBytes(of: srp.A) { Data($0) }
        } while A.first == 0
        let initResp = try await post(["A2k": A, "o": "init", "ps": ["s2k", "s2k_fo"], "u": email])
        guard let sp = initResp["sp"] as? String, let iter = initResp["i"] as? Int,
              let salt = initResp["s"] as? Data, let B = initResp["B"] as? Data, let c = initResp["c"] as? String else {
            throw SayoError(L("Apple did not accept the login request"))
        }
        let hashed = Crypto.sha256(Data(password.utf8))
        let pwInput = sp == "s2k_fo" ? Data(hashed.map { String(format: "%02x", $0) }.joined().utf8) : hashed
        let passKey = Crypto.pbkdf2(pwInput, salt: salt, iterations: iter)
        let rc = passKey.withUnsafeBytes { pk in
            salt.withUnsafeBytes { s in
                B.withUnsafeBytes { b in
                    sayo_srp_process(&srp, email, pk.bindMemory(to: UInt8.self).baseAddress, passKey.count,
                                     s.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     b.bindMemory(to: UInt8.self).baseAddress, B.count)
                }
            }
        }
        if rc != 0 { throw SayoError.last("SRP failed") }
        let M1 = withUnsafeBytes(of: srp.M1) { Data($0) }
        let M2 = withUnsafeBytes(of: srp.M2) { Data($0) }
        let K = withUnsafeBytes(of: srp.K) { Data($0) }
        let complete = try await post(["M1": M1, "c": c, "o": "complete", "u": email])
        if let serverM2 = complete["M2"] as? Data, serverM2 != M2 { throw SayoError(L("Apple server proof mismatch")) }
        guard let spd = complete["spd"] as? Data else { throw SayoError(L("Apple did not send session data")) }
        let key = Crypto.hmac(K, Data("extra data key:".utf8))
        let iv = Crypto.hmac(K, Data("extra data iv:".utf8)).prefix(16)
        let dec = try Crypto.cbcDecrypt(key: key, iv: Data(iv), spd)
        guard let sd = try PropertyListSerialization.propertyList(from: dec, format: nil) as? [String: Any],
              let adsid = sd["adsid"] as? String, let idms = sd["GsIdmsToken"] as? String,
              let sk = sd["sk"] as? Data, let cc = sd["c"] as? Data else {
            throw SayoError(L("Cannot read Apple session"))
        }
        var second: SecondFactor?
        if let st = complete["Status"] as? [String: Any], let au = st["au"] as? String {
            if au == "trustedDeviceSecondaryAuth" { second = .trustedDevice }
            else if au == "secondaryAuth" { second = .sms }
            else if au != "repair" { throw SayoError(L("Apple asks for an extra step. Finish it on appleid.apple.com and try again.") + " (\(au))") }
        }
        return LoginResult(adsid: adsid, idmsToken: idms, sk: sk, c: cc, needs2FA: second)
    }

    private func authRequest(_ url: URL, method: String, r: LoginResult, json: Bool = false) async throws -> URLRequest {
        try await anisette.fresh()
        var req = URLRequest(url: url)
        req.httpMethod = method
        anisette.apply(&req, json: json)
        let ident = Data("\(r.adsid):\(r.idmsToken)".utf8).base64EncodedString()
        req.setValue(ident, forHTTPHeaderField: "X-Apple-Identity-Token")
        return req
    }

    func requestCode(_ r: LoginResult, kind: SecondFactor) async throws {
        switch kind {
        case .trustedDevice:
            _ = try await URLSession.shared.data(for: authRequest(try anisette.url("trustedDeviceSecondaryAuth"), method: "GET", r: r))
        case .sms:
            _ = try await URLSession.shared.data(for: authRequest(URL(string: "https://gsa.apple.com/auth")!, method: "GET", r: r, json: true))
            var req = try await authRequest(URL(string: "https://gsa.apple.com/auth/verify/phone")!, method: "PUT", r: r, json: true)
            req.httpBody = try JSONSerialization.data(withJSONObject: ["phoneNumber": ["id": 1], "mode": "sms"])
            _ = try await URLSession.shared.data(for: req)
        }
    }

    func submitCode(_ code: String, r: LoginResult, kind: SecondFactor) async throws {
        switch kind {
        case .trustedDevice:
            var req = try await authRequest(try anisette.url("validateCode"), method: "GET", r: r)
            req.setValue(code, forHTTPHeaderField: "security-code")
            let (data, _) = try await URLSession.shared.data(for: req)
            if let p = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let err = grandSlamError((p["Status"] as? [String: Any]) ?? p) {
                throw err
            }
        case .sms:
            var req = try await authRequest(URL(string: "https://gsa.apple.com/auth/verify/phone/securitycode")!, method: "POST", r: r, json: true)
            req.httpBody = try JSONSerialization.data(withJSONObject: ["phoneNumber": ["id": 1], "securityCode": ["code": code], "mode": "sms"])
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw SayoError(L("Wrong code")) }
        }
    }

    func xcodeToken(_ r: LoginResult) async throws -> AppleSession {
        let app = "com.apple.gs.xcode.auth"
        let checksum = Crypto.hmac(r.sk, Data(("apptokens" + r.adsid + app).utf8))
        let resp = try await post(["app": [app], "c": r.c, "checksum": checksum,
                                   "o": "apptokens", "t": r.idmsToken, "u": r.adsid])
        guard let et = resp["et"] as? Data else { throw SayoError(L("Apple did not return an app token")) }
        let dec = try Crypto.gcmDecrypt(key: r.sk, et)
        guard let p = try PropertyListSerialization.propertyList(from: dec, format: nil) as? [String: Any],
              let t = p["t"] as? [String: Any], let x = t[app] as? [String: Any], let token = x["token"] as? String else {
            throw SayoError(L("Cannot read the Xcode token"))
        }
        var exp = Date().addingTimeInterval(3600 * 24 * 7)
        if let e = x["expiry"] as? Int { exp = Date(timeIntervalSince1970: TimeInterval(e) / 1000) }
        return AppleSession(adsid: r.adsid, idmsToken: r.idmsToken, xcodeToken: token, expiry: exp, email: email)
    }
}

final class DeveloperAPI {
    let session: AppleSession
    let anisette: Anisette
    static let clientID = "XABBG36SBA"

    init(session: AppleSession, anisette: Anisette) {
        self.session = session
        self.anisette = anisette
    }

    func call(_ action: String, ios: Bool = true, _ params: [String: Any] = [:]) async throws -> [String: Any] {
        try await anisette.fresh()
        let path = ios ? "ios/\(action).action" : "\(action).action"
        var r = URLRequest(url: URL(string: "https://developerservices2.apple.com/services/QH65B2/\(path)?clientId=\(DeveloperAPI.clientID)")!)
        r.httpMethod = "POST"
        var body = params
        body["clientId"] = DeveloperAPI.clientID
        body["protocolVersion"] = "QH65B2"
        body["requestId"] = UUID().uuidString.uppercased()
        body["userLocale"] = ["en_US"]
        r.httpBody = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        anisette.apply(&r)
        r.setValue("en-us", forHTTPHeaderField: "Accept-Language")
        r.setValue(session.adsid, forHTTPHeaderField: "X-Apple-I-Identity-Id")
        r.setValue(session.xcodeToken, forHTTPHeaderField: "X-Apple-GS-Token")
        let (data, _) = try await URLSession.shared.data(for: r)
        guard let p = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw SayoError(L("Unexpected developer services response"))
        }
        let code = (p["resultCode"] as? Int) ?? 0
        if code != 0 {
            let msg = (p["userString"] as? String) ?? (p["resultString"] as? String) ?? "error \(code)"
            throw SayoError(msg)
        }
        return p
    }

    func teams() async throws -> [[String: Any]] {
        try await call("listTeams", ios: false)["teams"] as? [[String: Any]] ?? []
    }

    func ensureDevice(team: String, udid: String) async throws {
        let devices = try await call("listDevices", ["teamId": team])["devices"] as? [[String: Any]] ?? []
        if devices.contains(where: { ($0["deviceNumber"] as? String)?.uppercased() == udid.uppercased() }) { return }
        _ = try await call("addDevice", ["teamId": team, "deviceNumber": udid, "name": UIDevice.current.name])
    }

    func createCertificate(team: String, keyTag: Data) async throws -> Data {
        let key = try LocalCA.makeKey(tag: keyTag)
        guard let pub = LocalCA.publicDER(key) else { throw SayoError(L("Cannot create key")) }
        var tbs = sayo_buf()
        let rc = pub.withUnsafeBytes { sayo_csr_info($0.bindMemory(to: UInt8.self).baseAddress, pub.count, "SayoSign", &tbs) }
        guard rc == 0, let tp = tbs.data else { sayo_buf_free(&tbs); throw SayoError(L("Cannot create CSR")) }
        let tbsData = Data(bytes: tp, count: tbs.len)
        sayo_buf_free(&tbs)
        guard let sig = LocalCA.sign(key, tbsData) else { throw SayoError(L("Cannot sign CSR")) }
        var csr = sayo_buf()
        _ = tbsData.withUnsafeBytes { t in
            sig.withUnsafeBytes { s in
                sayo_csr_finish(t.bindMemory(to: UInt8.self).baseAddress, tbsData.count, s.bindMemory(to: UInt8.self).baseAddress, sig.count, &csr)
            }
        }
        guard let cp = csr.data else { throw SayoError(L("Cannot create CSR")) }
        let csrDER = Data(bytes: cp, count: csr.len)
        sayo_buf_free(&csr)
        let b64 = csrDER.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let pem = "-----BEGIN CERTIFICATE REQUEST-----\n\(b64)\n-----END CERTIFICATE REQUEST-----\n"
        let existing = try await call("listAllDevelopmentCerts", ["teamId": team])["certificates"] as? [[String: Any]] ?? []
        for c in existing where (c["machineName"] as? String) == "SayoSign" {
            if let serial = c["serialNumber"] as? String {
                _ = try? await call("revokeDevelopmentCert", ["teamId": team, "serialNumber": serial])
            }
        }
        let submit: [String: Any]
        do {
            submit = try await call("submitDevelopmentCSR", ["teamId": team, "csrContent": pem,
                                                              "machineId": anisette.deviceID.uppercased(), "machineName": "SayoSign"])
        } catch {
            if let oldest = existing.first, let serial = oldest["serialNumber"] as? String {
                _ = try? await call("revokeDevelopmentCert", ["teamId": team, "serialNumber": serial])
                return try await createCertificate(team: team, keyTag: keyTag)
            }
            throw error
        }
        let req = submit["certRequest"] as? [String: Any] ?? [:]
        let serial = req["serialNumber"] as? String
        let certID = req["certificateId"] as? String
        for _ in 0..<5 {
            let all = try await call("listAllDevelopmentCerts", ["teamId": team])["certificates"] as? [[String: Any]] ?? []
            if let match = all.first(where: { ($0["serialNumber"] as? String) == serial || ($0["certificateId"] as? String) == certID }),
               let content = match["certContent"] as? Data {
                return content
            }
            if let content = req["certContent"] as? Data { return content }
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
        throw SayoError(L("Apple did not return the certificate"))
    }

    func profile(team: String, bundleID: String, name: String) async throws -> Data {
        let ids = try await call("listAppIds", ["teamId": team])["appIds"] as? [[String: Any]] ?? []
        var appIdId = ids.first(where: { ($0["identifier"] as? String) == bundleID })?["appIdId"] as? String
        if appIdId == nil {
            let clean = name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
            let display = String(String.UnicodeScalarView(clean)).trimmingCharacters(in: .whitespaces)
            let resp = try await call("addAppId", ["teamId": team, "identifier": bundleID, "name": display.isEmpty ? "SayoSign App" : display])
            appIdId = (resp["appId"] as? [String: Any])?["appIdId"] as? String
        }
        guard let aid = appIdId else { throw SayoError(L("Cannot register the App ID")) }
        let resp = try await call("downloadTeamProvisioningProfile", ["teamId": team, "appIdId": aid])
        guard let p = resp["provisioningProfile"] as? [String: Any], let enc = p["encodedProfile"] as? Data else {
            throw SayoError(L("Apple did not return a provisioning profile"))
        }
        return enc
    }
}

enum AppleAccount {
    static func keyTag(_ id: UUID) -> Data { Data("dev.murk.sayosign.appleid.\(id.uuidString)".utf8) }

    static func saveSession(_ s: AppleSession, for id: UUID) {
        if let d = try? JSONEncoder().encode(s), let str = String(data: d, encoding: .utf8) {
            Keychain.set(str, for: "appleid.session." + id.uuidString)
        }
    }

    static func session(for id: UUID) -> AppleSession? {
        guard let s = Keychain.get("appleid.session." + id.uuidString), let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AppleSession.self, from: d)
    }

    static func profile(for cert: StoredCertificate, bundleID: String, name: String, anisetteURL: String) async throws -> (Data, String) {
        guard let s = session(for: cert.id) else { throw SayoError(L("Sign in to your Apple ID again")) }
        if s.expiry < Date() { throw SayoError(L("Your Apple ID session expired, sign in again")) }
        let ani = try await Anisette.fetch(anisetteURL)
        let api = DeveloperAPI(session: s, anisette: ani)
        let team = cert.profile.teamID
        let finalID = bundleID.hasSuffix("." + team) ? bundleID : bundleID + "." + team
        let data = try await api.profile(team: team, bundleID: finalID, name: name)
        return (data, finalID)
    }
}

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

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text(L("Your password is sent only to Apple. Free accounts get 7-day certificates and up to 3 apps at a time."))) {
                    HStack {
                        Spacer()
                        Image(systemName: "applelogo").font(.system(size: 42)).foregroundStyle(Theme.gradient)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                if step == 0 {
                    Section(header: Text(L("Apple ID"))) {
                        TextField("email@icloud.com", text: $email).keyboardType(.emailAddress).autocapitalization(.none).disableAutocorrection(true)
                        SecureField(L("Password"), text: $password)
                    }
                    Section(header: Text(L("Anisette server")), footer: Text(L("Apple only accepts Mac-based anisette servers since October 2026."))) {
                        Picker(L("Server"), selection: $state.settings.anisetteURL) {
                            ForEach(Anisette.presets, id: \.url) { p in Text(p.name).tag(p.url) }
                            if !Anisette.presets.contains(where: { $0.url == state.settings.anisetteURL }) {
                                Text(state.settings.anisetteURL).tag(state.settings.anisetteURL)
                            }
                        }
                    }
                    Section(header: Text("UDID"), footer: Text(L("Your iPhone UDID is needed to register it with Apple. Find it in Finder/iTunes or on a UDID website."))) {
                        TextField("00008110-000000000000001E", text: $udid).autocapitalization(.allCharacters).disableAutocorrection(true)
                    }
                    Section {
                        Button { Task { await start() } } label: {
                            HStack { if working { ProgressView().tint(.white) }; Text(L("Sign in")) }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(working || email.isEmpty || password.isEmpty || udid.count < 20)
                        .listRowBackground(Color.clear)
                    }
                } else if step == 1 {
                    Section(header: Text(L("Two-factor code")), footer: Text(factor == .sms ? L("A code was sent by SMS.") : L("Check your other Apple device for the code."))) {
                        TextField("123456", text: $code).keyboardType(.numberPad).font(.title2.monospacedDigit())
                        Button(L("Send SMS instead")) { Task { await switchToSMS() } }
                    }
                    Section {
                        Button { Task { await verify() } } label: {
                            HStack { if working { ProgressView().tint(.white) }; Text(L("Verify")) }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(working || code.count < 6)
                        .listRowBackground(Color.clear)
                    }
                } else if step == 2 {
                    Section(header: Text(L("Choose a team"))) {
                        ForEach(teams.indices, id: \.self) { i in
                            let t = teams[i]
                            Button {
                                Task { await finish(team: t) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(t["name"] as? String ?? "Team").font(.headline)
                                    Text((t["teamId"] as? String ?? "") + " · " + (t["type"] as? String ?? "")).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .disabled(working)
                        }
                    }
                }
                if !log.isEmpty {
                    Section(header: Text(L("Progress"))) {
                        ForEach(log.indices, id: \.self) { i in
                            Label(log[i], systemImage: "checkmark.circle.fill").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                if let e = error { Section { Text(e).foregroundColor(.red) } }
            }
            .navigationTitle(L("Apple ID"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } } }
            .onAppear { udid = state.settings.udid }
        }
    }

    func add(_ s: String) { log.append(s) }

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
                // Stale or rejected provisioning: start a fresh identity once and retry.
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
            let der = try await api.createCertificate(team: teamID, keyTag: AppleAccount.keyTag(id))
            add(L("Certificate created"))
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
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
