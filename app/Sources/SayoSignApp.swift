import SwiftUI
import UniformTypeIdentifiers

struct SayoSignApp: App {
    @StateObject private var state = AppState.shared
    @StateObject private var certImport = CertificateImportCoordinator.shared
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            AppShell(state: state, certImport: certImport, localization: localization)
                .tint(Theme.rose)
                .preferredColorScheme(state.settings.appearance == 1 ? .light : state.settings.appearance == 2 ? .dark : nil)
                .environment(\.locale, localization.locale)
                .environment(\.layoutDirection, localization.layoutDirection)
                .onOpenURL { state.handleOpen($0) }
        }
    }
}

private struct AppShell: View {
    @ObservedObject var state: AppState
    @ObservedObject var certImport: CertificateImportCoordinator
    @ObservedObject var localization: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            RootView()
                .environmentObject(state)
                .environmentObject(certImport)
                .id(localization.revision)
                .opacity(showLaunch ? 0 : 1)

            if showLaunch {
                LaunchExperienceView()
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
                    .zIndex(100)
            }
        }
        .onAppear {
            guard showLaunch else { return }
            guard !reduceMotion else {
                showLaunch = false
                return
            }
            // The signing engine and inbox scan already run behind this overlay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                withAnimation(.easeInOut(duration: 0.55)) { showLaunch = false }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var certImport: CertificateImportCoordinator
    @Environment(\.scenePhase) var phase
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $state.tab) {
                LibraryView()
                    .tabItem { Label(L("Library"), systemImage: "square.stack.3d.up.fill") }
                    .tag(0)
                CertificatesView()
                    .tabItem { Label(L("Certificates"), systemImage: "checkmark.seal.fill") }
                    .tag(1)
                SourcesView()
                    .tabItem { Label(L("Sources"), systemImage: "globe") }
                    .tag(2)
                SettingsView()
                    .tabItem { Label(L("Settings"), systemImage: "gearshape.fill") }
                    .tag(3)
            }
            .tint(Theme.rose)

            if let t = state.toast {
                ToastView(text: t)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .onTapGesture { state.toast = nil }
                    .zIndex(10)
                    .accessibilityAction(named: L("Dismiss")) { state.toast = nil }
            }
            if let b = state.busy {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.coral)
                    Text(b).font(SayoType.captionStrong)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .glassPanelCompat()
                .padding(.top, 8)
                .zIndex(9)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: state.toast)
        .animation(.easeInOut(duration: 0.25), value: state.busy)
        .sheet(isPresented: $certImport.presented) {
            ImportCertificateView(prefillP12: certImport.p12, prefillProfile: certImport.profile)
                .environmentObject(state)
        }
        .sheet(item: $state.pendingSign) { app in
            SignView(app: app).environmentObject(state)
        }
        .onChange(of: phase) { p in
            if p == .active { Task { await state.scanInbox() } }
        }
        .task {
            if Diagnostics.enabled { await Diagnostics.run(state) }
            await state.scanInbox()
            if state.certificates.contains(where: { $0.ocspChecked == nil || $0.ocspChecked! < Date().addingTimeInterval(-3600) }) {
                await state.refreshAllOCSP()
            }
        }
    }
}

extension UTType {
    static let ipa = UTType(filenameExtension: "ipa") ?? .data
    static let tipa = UTType(filenameExtension: "tipa") ?? .data
    static let p12 = UTType(filenameExtension: "p12") ?? .data
    static let mobileprovision = UTType(filenameExtension: "mobileprovision") ?? .data
    static let deb = UTType(filenameExtension: "deb") ?? .data
    static let dylib = UTType(filenameExtension: "dylib") ?? .data
}
