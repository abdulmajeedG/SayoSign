import SwiftUI
import UIKit

// MARK: - Haptics

enum Haptics {
    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Headers

struct PageTitle: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow = eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(Theme.coral)
            }
            Text(title)
                .font(SayoType.hero)
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    let title: String
    var subtitle: String? = nil
    var accessory: String? = nil
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 7) {
                if let symbol = symbol {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.coral.opacity(0.11))
                        Image(systemName: symbol)
                            .font(.system(size: 9, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Theme.coral)
                    }
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.textSecondary)
                Spacer(minLength: 8)
                if let accessory = accessory {
                    Text(accessory)
                        .font(SayoType.micro)
                        .foregroundColor(Theme.textTertiary)
                }
            }
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(SayoType.caption)
                    .foregroundColor(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct BrandHeader: View {
    let compact: Bool
    var trailing: AnyView? = nil

    init(compact: Bool = false, trailing: AnyView? = nil) {
        self.compact = compact
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            BrandMark(size: compact ? 32 : 38)
            VStack(alignment: .leading, spacing: 0) {
                Text("SayoSign")
                    .font(.system(compact ? .headline : .title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.gradient)
                if !compact {
                    Text(L("On-device IPA signer"))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Spacer()
            if let trailing = trailing { trailing }
        }
    }
}

// MARK: - Search

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
            TextField(placeholder, text: $text)
                .font(SayoType.body)
                .foregroundColor(Theme.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    Haptics.selection()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Clear"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Segmented control

struct SayoSegmentedControl: View {
    @Binding var selection: Int
    let items: [(title: String, count: Int?)]
    @Namespace private var ns
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                Button {
                    guard selection != index else { return }
                    Haptics.selection()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        selection = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                        if let count = item.count {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(selection == index ? Color.white.opacity(0.22) : Theme.surfaceInset))
                                .foregroundColor(selection == index ? .white.opacity(0.9) : Theme.textTertiary)
                        }
                    }
                    .foregroundColor(selection == index ? .white : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == index {
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .fill(Theme.inkGradient)
                                .matchedGeometryEffect(id: "segment", in: ns)
                                .shadow(color: Theme.rose.opacity(0.22), radius: 9, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surface.opacity(scheme == .dark ? 0.9 : 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.border.opacity(0.8), lineWidth: 0.7)
                )
        )
    }
}

// MARK: - Quick actions

struct QuickActionTile: View {
    let title: String
    let subtitle: String?
    let symbol: String
    var tint: Color = Theme.coral
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    IconBadge(symbol: symbol, tint: tint, size: 42)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textTertiary.opacity(0.55))
                        .flipsForRightToLeftLayoutDirection(true)
                        .padding(7)
                        .background(Circle().fill(Theme.surfaceInset.opacity(0.55)))
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(SayoType.micro)
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .stroke(Theme.border, lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Rows

struct DividerSoft: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border.opacity(0.7))
            .frame(height: 0.7)
    }
}

struct SayoInfoRow: View {
    let title: String
    let value: String
    var mono: Bool = false
    init(_ t: String, _ v: String, mono: Bool = false) { title = t; value = v; self.mono = mono }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(SayoType.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(mono ? SayoType.mono : SayoType.captionStrong)
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct LabeledValue: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    var tint: Color = Theme.coral
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(tint)
                .monospacedDigit()
            Text(label)
                .font(SayoType.micro)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(tint.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(tint.opacity(0.09), lineWidth: 0.6)
                )
        )
    }
}

// MARK: - Banners

struct BannerView: View {
    enum Kind { case info, success, warning, error
        var tint: Color {
            switch self {
            case .info: return Theme.info
            case .success: return Theme.success
            case .warning: return Theme.warning
            case .error: return Theme.danger
            }
        }
        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.seal.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }
    }

    let kind: Kind
    let text: String
    var title: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(kind.tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                if let title = title {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                Text(text)
                    .font(SayoType.caption)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle, action: action)
                        .font(SayoType.captionStrong)
                        .foregroundColor(kind.tint)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(kind.tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(kind.tint.opacity(0.13), lineWidth: 0.7)
                )
        )
    }
}

// MARK: - Progress

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6
    var tint: Color = Theme.coral
    var track: Color = Theme.border
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle().stroke(track.opacity(0.55), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Theme.inkGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
        }
        .frame(width: size, height: size)
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

struct StepRail: View {
    let steps: [String]
    let current: Int
    var failed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(stateColor(i))
                                .frame(width: 24, height: 24)
                            if i < current || (current >= steps.count && !failed) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            } else if i == current {
                                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.6).frame(width: 9, height: 9)
                            } else {
                                Circle().fill(Theme.surfaceFloat).frame(width: 8, height: 8)
                            }
                        }
                        if i < steps.count - 1 {
                            Rectangle()
                                .fill(i < current ? Theme.coral.opacity(0.55) : Theme.border)
                                .frame(width: 1.5, height: 20)
                        }
                    }
                    Text(steps[i])
                        .font(i == current ? .system(.subheadline, design: .rounded).weight(.semibold) : SayoType.subheadline)
                        .foregroundColor(i <= current ? Theme.textPrimary : Theme.textTertiary)
                        .padding(.top, 2)
                    Spacer(minLength: 0)
                    if i == current && current < steps.count && !failed {
                        ProgressView().scaleEffect(0.7)
                    }
                }
            }
        }
    }

    func stateColor(_ i: Int) -> Color {
        if failed && i == current { return Theme.danger }
        if i < current || current >= steps.count { return Theme.success }
        if i == current { return Theme.coral }
        return Theme.surfaceInset
    }
}

// MARK: - Settings controls

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let symbol = symbol {
                IconBadge(symbol: symbol, tint: Theme.coral, size: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SayoType.bodyStrong)
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(SayoType.micro)
                        .foregroundColor(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.coral)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

struct SettingsLinkRow: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String = "chevron.right"
    var tint: Color = Theme.coral
    var value: String? = nil
    var destructive: Bool = false
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: symbol, tint: destructive ? Theme.danger : tint, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SayoType.bodyStrong)
                        .foregroundColor(destructive ? Theme.danger : Theme.textPrimary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(SayoType.micro)
                            .foregroundColor(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let value = value {
                    Text(value)
                        .font(SayoType.captionStrong)
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textTertiary.opacity(0.7))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(accessibilityID ?? "settings.row." + title)
    }
}

struct SayoTextField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var secure: Bool = false
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization? = nil
    var mono: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundColor(Theme.textTertiary)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(mono ? SayoType.mono : SayoType.body)
            .foregroundColor(Theme.textPrimary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .disableAutocorrection(true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.surfaceInset.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.7)
                )
        )
    }
}

/// A labelled field whose input sits on the trailing edge, like the original settings form.
struct SayoLabeledField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var mono: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(SayoType.body)
                .foregroundColor(Theme.textPrimary)
            Spacer(minLength: 8)
            TextField(placeholder, text: $text)
                .font(mono ? SayoType.mono : SayoType.body)
                .multilineTextAlignment(.trailing)
                .foregroundColor(Theme.textSecondary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .lineLimit(1)
        }
        .padding(.vertical, 11)
    }
}

struct AppearanceOption: View {
    let title: String
    let symbol: String
    let selected: Bool
    var accessibilityID: String = ""
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(selected ? .white : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.surfaceInset.opacity(0.55)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(selected ? Color.white.opacity(0.18) : Theme.border.opacity(0.8), lineWidth: 0.7)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityID)
    }
}

struct LanguageRow: View {
    let language: AppLanguage
    let selected: Bool
    var accessibilityID: String = ""
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selected ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.surfaceInset))
                        .frame(width: 34, height: 34)
                    Text(language.initial)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(selected ? .white : Theme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(language.nativeName)
                        .font(SayoType.bodyStrong)
                        .foregroundColor(Theme.textPrimary)
                    Text(language.englishName)
                        .font(SayoType.micro)
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.coral)
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - Misc

struct SuccessSeal: View {
    @State private var appeared = false
    var size: CGFloat = 92

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.success.opacity(0.10))
                .frame(width: size + 24, height: size + 24)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            Circle()
                .fill(Theme.success.opacity(0.16))
                .frame(width: size, height: size)
                .scaleEffect(appeared ? 1 : 0.7)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundColor(Theme.success)
                .scaleEffect(appeared ? 1 : 0.4)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.05)) {
                appeared = true
            }
            Haptics.success()
        }
        .accessibilityHidden(true)
    }
}

struct CountBadge: View {
    let count: Int
    var tint: Color = Theme.coral
    var body: some View {
        Text("\(count)")
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.11)))
    }
}

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    @State private var shimmer = false
    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Theme.border.opacity(0.55))
            .frame(width: width, height: height)
            .overlay(
                LinearGradient(colors: [.clear, Theme.surface.opacity(0.7), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .offset(x: shimmer ? 160 : -160)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
            .accessibilityHidden(true)
    }
}

struct Chevron: View {
    var expanded: Bool
    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textTertiary)
            .rotationEffect(.degrees(expanded ? 180 : 0))
    }
}

extension View {
    /// Rounded card used by lightweight lists without wrapping in another VStack.
    func sayoSurface(radius: CGFloat = Theme.Radius.card) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.border, lineWidth: 0.7)
                    )
            )
    }

    func sayoScreen() -> some View {
        self
            .background(SayoBackground())
            .scrollContentBackgroundCompat()
    }

    @ViewBuilder func scrollContentBackgroundCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

extension Date {
    var sayoRelative: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: Date())
    }
}
