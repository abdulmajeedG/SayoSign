import SwiftUI

struct SourcesView: View {
    @EnvironmentObject var state: AppState
    @State private var adding = false
    @State private var newURL = ""
    @State private var search = ""
    @State private var filter: UUID?

    var allApps: [RepoApp] {
        let apps = state.sources.filter { filter == nil || $0.id == filter }.flatMap { $0.apps }
        if search.isEmpty { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.bundleID.localizedCaseInsensitiveContains(search)
                || $0.developer.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground(accent: Theme.lilac)
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        header
                        PageTitle(eyebrow: L("Discover"),
                                  title: L("Sources"),
                                  subtitle: L("Browse repositories and download apps in a tap."))
                            .padding(.top, 2)
                        SearchField(text: $search, placeholder: L("Search apps"))
                        if state.sources.isEmpty {
                            emptySources
                        } else {
                            sourcesStrip
                            appsSection
                        }
                    }
                    .padding(.horizontal, Theme.Space.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
                .refreshable { await state.refreshSources() }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $adding) {
                AddSourceSheet(urlText: $newURL) { raw in
                    Task { await state.addSource(raw) }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        BrandHeader(compact: true, trailing: AnyView(
            Button {
                Haptics.light()
                adding = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 0.7)))
            }
            .accessibilityLabel(L("Add source"))
            .accessibilityIdentifier("sources.add")
        ))
    }

    private var sourcesStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Your sources"), accessory: "\(state.sources.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { filter = nil }
                    } label: {
                        allSourcesCard
                    }
                    .buttonStyle(PressableStyle())

                    ForEach(state.sources) { source in
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                filter = filter == source.id ? nil : source.id
                            }
                        } label: {
                            sourceCard(source)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button { UIPasteboard.general.string = source.url } label: { Label(L("Copy link"), systemImage: "doc.on.doc") }
                            Button(role: .destructive) {
                                state.removeSource(source)
                                if filter == source.id { filter = nil }
                            } label: { Label(L("Remove"), systemImage: "trash") }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var allSourcesCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(filter == nil ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.surfaceInset))
                    .frame(width: 38, height: 38)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(filter == nil ? .white : Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(L("All sources"))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(state.sources.reduce(0) { $0 + $1.apps.count })")
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(width: 118, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(filter == nil ? Theme.coral.opacity(0.32) : Theme.border, lineWidth: filter == nil ? 1.1 : 0.7)
                )
        )
    }

    private func sourceCard(_ source: RepoSource) -> some View {
        let selected = filter == source.id
        return VStack(alignment: .leading, spacing: 9) {
            AppIconView(image: nil, url: source.iconURL, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(source.name)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Text("\(source.apps.count)")
                    Text(L("Apps"))
                }
                .font(SayoType.micro)
                .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(width: 118, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(selected ? Theme.coral.opacity(0.34) : Theme.border, lineWidth: selected ? 1.1 : 0.7)
                )
        )
    }

    private var appsSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(filter == nil ? L("All apps") : (state.sources.first { $0.id == filter }?.name ?? L("Apps")))
                    .font(SayoType.display)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("\(allApps.count)")
                    .font(SayoType.numberSmall)
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, 2)

            if allApps.isEmpty {
                EmptyState(title: L("Nothing found"),
                           subtitle: L("Try another search or refresh your sources."),
                           symbol: "magnifyingglass")
            }

            LazyVStack(spacing: 10) {
                ForEach(allApps) { app in
                    NavigationLink(destination: RepoAppDetail(app: app)) {
                        RepoAppRow(app: app)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var emptySources: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.lilac.opacity(0.08)).frame(width: 108, height: 108)
                Circle().stroke(Theme.lilac.opacity(0.12), lineWidth: 1).frame(width: 82, height: 82)
                Image(systemName: "globe")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 6) {
                Text(L("No sources"))
                    .font(SayoType.title3)
                    .foregroundColor(Theme.textPrimary)
                Text(L("Add an AltStore, SideStore, Feather or ESign repository URL to browse apps."))
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { adding = true } label: {
                Label(L("Add source"), systemImage: "plus")
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

struct RepoAppRow: View {
    @EnvironmentObject var state: AppState
    let app: RepoApp

    var body: some View {
        HStack(spacing: 13) {
            AppIconView(image: nil, url: app.iconURL, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(app.subtitle.isEmpty ? app.developer : app.subtitle)
                    .font(SayoType.micro)
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if !app.version.isEmpty { Pill(text: "v" + app.version) }
                    if app.size > 0 { Pill(text: formatSize(app.size), color: Theme.textSecondary) }
                }
            }
            Spacer(minLength: 4)
            Button {
                Haptics.medium()
                if let u = URL(string: app.downloadURL) {
                    Task { await state.download(u, name: app.name) }
                    state.show(LF("Downloading %@", app.name))
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 12, weight: .semibold))
                    Text(L("Get"))
                }
            }
            .buttonStyle(SmallButtonStyle())
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                .shadow(color: Color.black.opacity(0.03), radius: 12, y: 5)
        )
    }
}

struct RepoAppDetail: View {
    @EnvironmentObject var state: AppState
    let app: RepoApp
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            SayoBackground(accent: Theme.lilac)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    metadata
                    if !app.screenshots.isEmpty { screenshots }
                    if !app.description.isEmpty { about }
                }
                .padding(.horizontal, Theme.Space.screen)
                .padding(.vertical, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.coral.opacity(0.10))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                AppIconView(image: nil, url: app.iconURL, size: 100)
                    .shadow(color: Color.black.opacity(scheme == .dark ? 0.5 : 0.16), radius: 20, y: 12)
            }
            VStack(spacing: 4) {
                Text(app.name)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(app.developer)
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Haptics.medium()
                if let u = URL(string: app.downloadURL) {
                    Task { await state.download(u, name: app.name) }
                    state.tab = 0
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text(L("Get"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: false))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var metadata: some View {
        HStack(spacing: 0) {
            if !app.version.isEmpty {
                LabeledValue(label: L("Version"), value: app.version)
                DividerSoft().frame(height: 28).padding(.horizontal, 12)
            }
            if app.size > 0 {
                LabeledValue(label: L("Size"), value: formatSize(app.size))
                if !app.bundleID.isEmpty {
                    DividerSoft().frame(height: 28).padding(.horizontal, 12)
                }
            }
            if !app.bundleID.isEmpty {
                LabeledValue(label: L("Bundle ID"), value: app.bundleID)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
        )
    }

    private var screenshots: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: L("Screenshots"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(app.screenshots, id: \.self) { s in
                        AsyncImage(url: URL(string: s)) { p in
                            if let i = p.image {
                                i.resizable().scaledToFit()
                            } else {
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Theme.surfaceInset)
                                    .overlay(ProgressView().scaleEffect(0.8))
                            }
                        }
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
                    }
                }
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(title: L("About this app"))
            Text(app.description)
                .font(SayoType.body)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.border, lineWidth: 0.7))
        )
    }
}

struct AddSourceSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @Binding var urlText: String
    let onAdd: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                SayoBackground(accent: Theme.lilac)
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "globe", tint: Theme.lilac, size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("Add source"))
                                .font(SayoType.title)
                                .foregroundColor(Theme.textPrimary)
                            Text(L("Paste a repository link"))
                                .font(SayoType.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("URL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.9)
                            .foregroundColor(Theme.textTertiary)
                        TextField("https://example.com/repo.json", text: $urlText)
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
                    Text(L("Works with AltStore, SideStore, Feather and ESign repositories."))
                        .font(SayoType.caption)
                        .foregroundColor(Theme.textTertiary)
                    Button {
                        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !raw.isEmpty else { return }
                        Haptics.medium()
                        onAdd(raw)
                        urlText = ""
                        dismiss()
                    } label: {
                        Label(L("Add"), systemImage: "plus")
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
