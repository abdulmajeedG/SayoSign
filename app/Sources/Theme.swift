import SwiftUI
import UIKit

// MARK: - SayoSign design tokens
//
// "Ink & Ribbon": warm porcelain surfaces in light mode, deep plum ink in dark mode,
// a coral-to-rose ribbon accent and restrained gold/lilac highlights. Everything here is
// presentation-only: colors, type, spacing, radii, shadows and reusable styles.

enum Theme {
    // MARK: Brand

    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    /// The signature SayoSign coral.
    static let coral = adaptive(light: rgb(239, 86, 111), dark: rgb(255, 117, 142))
    /// A deeper rose for contrast and gradients.
    static let rose = adaptive(light: rgb(203, 45, 79), dark: rgb(255, 92, 125))
    /// A soft apricot for highlights.
    static let peach = adaptive(light: rgb(255, 184, 164), dark: rgb(255, 194, 178))
    /// The lightest warm tint.
    static let cream = adaptive(light: rgb(255, 246, 242), dark: rgb(45, 31, 39))
    /// Deep ribbon used sparingly for emphasis.
    static let ribbon = adaptive(light: rgb(186, 31, 66), dark: rgb(255, 143, 163))

    // MARK: Semantic surfaces

    /// Main canvas.
    static let background = adaptive(light: rgb(247, 242, 242), dark: rgb(17, 12, 17))
    /// A slightly lifted canvas for grouped content.
    static let backgroundRaised = adaptive(light: rgb(251, 247, 246), dark: rgb(22, 16, 22))
    /// Card and sheet surface.
    static let surface = adaptive(light: rgb(255, 252, 250), dark: rgb(29, 22, 29))
    /// A secondary surface inside cards (fields, inset rows).
    static let surfaceInset = adaptive(light: rgb(247, 240, 241), dark: rgb(38, 29, 37))
    /// Floating controls such as search fields.
    static let surfaceFloat = adaptive(light: rgb(255, 255, 255), dark: rgb(35, 26, 34))

    // MARK: Ink

    static let textPrimary = adaptive(light: rgb(30, 23, 27), dark: rgb(248, 241, 243))
    static let textSecondary = adaptive(light: rgb(117, 103, 110), dark: rgb(180, 165, 174))
    static let textTertiary = adaptive(light: rgb(157, 143, 150), dark: rgb(139, 126, 135))
    static let border = adaptive(light: rgb(234, 223, 226), dark: rgb(56, 43, 54))
    static let borderStrong = adaptive(light: rgb(220, 204, 209), dark: rgb(74, 57, 69))

    // MARK: Status

    static let success = adaptive(light: rgb(38, 148, 107), dark: rgb(92, 214, 166))
    static let warning = adaptive(light: rgb(207, 130, 34), dark: rgb(255, 190, 105))
    static let danger = adaptive(light: rgb(202, 48, 66), dark: rgb(255, 107, 122))
    static let info = adaptive(light: rgb(74, 111, 191), dark: rgb(132, 168, 255))
    static let lilac = adaptive(light: rgb(130, 100, 200), dark: rgb(183, 157, 255))
    static let mint = adaptive(light: rgb(42, 143, 143), dark: rgb(101, 216, 210))
    static let gold = adaptive(light: rgb(177, 132, 44), dark: rgb(240, 199, 116))

    static let shadow = adaptive(light: UIColor(red: 0.24, green: 0.09, blue: 0.14, alpha: 0.10),
                                 dark: UIColor(red: 0, green: 0, blue: 0, alpha: 0.35))

    // MARK: Gradients

    static let gradient = LinearGradient(colors: [coral, rose],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let gradientSoft = LinearGradient(colors: [coral.opacity(0.18), peach.opacity(0.10)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let ribbonGradient = LinearGradient(colors: [ribbon, coral, peach],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
    static let goldGradient = LinearGradient(colors: [gold.opacity(0.95), peach.opacity(0.9)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let inkGradient = LinearGradient(colors: [ribbon, rose, coral.opacity(0.92)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
    static let soft = LinearGradient(colors: [coral.opacity(0.13), coral.opacity(0.07)],
                                     startPoint: .top, endPoint: .bottom)

    // MARK: Layout tokens

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 26
        static let xxl: CGFloat = 34
        static let huge: CGFloat = 48
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let xs: CGFloat = 10
        static let sm: CGFloat = 14
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let xl: CGFloat = 30
        static let card: CGFloat = 24
        static let control: CGFloat = 16
        static let pill: CGFloat = 999
    }

    enum Shadow {
        static func card(_ colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            colorScheme == .dark
                ? (Color.black.opacity(0.34), 16, 8)
                : (Color(red: 0.35, green: 0.16, blue: 0.21).opacity(0.08), 18, 9)
        }
    }
}

// MARK: - Typography

enum SayoType {
    static let hero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let display = Font.system(.title, design: .rounded).weight(.bold)
    static let title = Font.system(.title2, design: .rounded).weight(.bold)
    static let title3 = Font.system(.title3, design: .rounded).weight(.semibold)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.body
    static let bodyStrong = Font.body.weight(.semibold)
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let label = Font.subheadline.weight(.semibold)
    static let caption = Font.caption
    static let captionStrong = Font.caption.weight(.semibold)
    static let micro = Font.caption2.weight(.medium)
    static let number = Font.system(.title2, design: .rounded).weight(.bold).monospacedDigit()
    static let numberSmall = Font.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit()
    static let mono = Font.system(.caption, design: .monospaced)
    static let monoSmall = Font.system(.caption2, design: .monospaced)
}

// MARK: - Brand mark

struct Bow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let c = CGPoint(x: r.midX, y: r.minY + h * 0.38)
        p.move(to: c)
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.08), control1: CGPoint(x: r.minX + w * 0.32, y: r.minY - h * 0.05), control2: CGPoint(x: r.minX + w * 0.05, y: r.minY - h * 0.05))
        p.addCurve(to: c, control1: CGPoint(x: r.minX - w * 0.04, y: r.minY + h * 0.55), control2: CGPoint(x: r.minX + w * 0.25, y: r.minY + h * 0.75))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.08), control1: CGPoint(x: r.maxX - w * 0.32, y: r.minY - h * 0.05), control2: CGPoint(x: r.maxX - w * 0.05, y: r.minY - h * 0.05))
        p.addCurve(to: c, control1: CGPoint(x: r.maxX + w * 0.04, y: r.minY + h * 0.55), control2: CGPoint(x: r.maxX - w * 0.25, y: r.minY + h * 0.75))
        p.move(to: c)
        p.addLine(to: CGPoint(x: r.minX + w * 0.28, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.40, y: r.maxY - h * 0.08))
        p.addLine(to: c)
        p.addLine(to: CGPoint(x: r.maxX - w * 0.28, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.40, y: r.maxY - h * 0.08))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: c.x - w * 0.09, y: c.y - h * 0.11, width: w * 0.18, height: h * 0.22))
        return p
    }
}

struct BrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
            LinearGradient(colors: [Color.white.opacity(0.12), .clear],
                           startPoint: .topLeading, endPoint: .center)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.rose.opacity(0.18), radius: size * 0.22, y: size * 0.07)
        .accessibilityHidden(true)
    }
}

// MARK: - Cards

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .stroke(Theme.border.opacity(0.9), lineWidth: 0.7)
                    )
                    .shadow(color: Color.black.opacity(0.045), radius: 16, y: 8)
            )
    }
}

struct SayoCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    var tint: Color? = nil
    let content: Content
    init(padding: CGFloat = Theme.Space.md, tint: Color? = nil, @ViewBuilder _ content: () -> Content) {
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(Theme.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .stroke(Theme.border.opacity(0.85), lineWidth: 0.7)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 18, y: 10)
            )
    }
}

struct GlassPanel<Content: View>: View {
    var radius: CGFloat = Theme.Radius.card
    let content: Content
    init(radius: CGFloat = Theme.Radius.card, @ViewBuilder _ content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Theme.surface.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Backgrounds

struct SayoBackground: View {
    @Environment(\.colorScheme) private var scheme
    var accent: Color = Theme.coral

    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [accent.opacity(scheme == .dark ? 0.16 : 0.13), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 430)
                .offset(x: -80, y: -190)
            RadialGradient(colors: [Theme.lilac.opacity(scheme == .dark ? 0.10 : 0.07), .clear],
                           center: .bottomTrailing, startRadius: 20, endRadius: 420)
                .offset(x: 100, y: 220)
            if scheme == .light {
                LinearGradient(colors: [Color.white.opacity(0.25), .clear],
                               startPoint: .top, endPoint: .center)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Legacy icon view, redesigned

struct AppIconView: View {
    let image: UIImage?
    var url: String? = nil
    var size: CGFloat = 54
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image).resizable()
            } else if let s = url, let u = URL(string: s), !s.isEmpty {
                AsyncImage(url: u) { phase in
                    if let img = phase.image { img.resizable() } else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
                .stroke(Theme.borderStrong.opacity(0.65), lineWidth: 0.7)
        )
        .overlay(
            LinearGradient(colors: [Color.white.opacity(0.20), .clear],
                           startPoint: .topLeading, endPoint: .center)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous))
                .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(0.10), radius: size * 0.12, y: size * 0.05)
    }

    var placeholder: some View {
        ZStack {
            Theme.inkGradient
            Bow().fill(Color.white.opacity(0.94)).padding(size * 0.23)
        }
    }
}

// MARK: - Pills and chips

struct Pill: View {
    let text: String
    var color: Color = Theme.coral
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon).font(.system(size: 8.5, weight: .bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(color.opacity(0.13)))
        .foregroundColor(color)
    }
}

struct IconBadge: View {
    let symbol: String
    var tint: Color = Theme.coral
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.075)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(
                    LinearGradient(colors: [Color.white.opacity(0.42), tint.opacity(0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8
                )
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.30), .clear],
                                     center: .topLeading, startRadius: 1, endRadius: size * 0.62))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.22), radius: 1.2, y: 0.6)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.16), radius: size * 0.22, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 18 : 20)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.inkGradient)
                    .shadow(color: Theme.rose.opacity(configuration.isPressed ? 0.12 : 0.28),
                            radius: configuration.isPressed ? 6 : 14, y: configuration.isPressed ? 3 : 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if !pressed { Haptics.light() }
            }
    }
}

struct SmallButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundColor(filled ? .white : Theme.rose)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(filled ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.coral.opacity(0.11)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(filled ? Color.white.opacity(0.16) : Theme.coral.opacity(0.10), lineWidth: 0.6)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.rose
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 0.7)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct RoundIconButtonStyle: ButtonStyle {
    var tint: Color = Theme.textPrimary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(Theme.surface)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 0.7))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let title: String
    let subtitle: String
    var symbol: String = "shippingbox.fill"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            ZStack {
                Circle()
                    .fill(Theme.coral.opacity(0.08))
                    .frame(width: 104, height: 104)
                Circle()
                    .stroke(Theme.coral.opacity(0.10), lineWidth: 1)
                    .frame(width: 80, height: 80)
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(SayoType.title3)
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(SayoType.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toast

struct ToastView: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.inkGradient).frame(width: 26, height: 26)
                Bow().fill(Color.white).frame(width: 13, height: 11)
            }
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .overlay(Capsule(style: .continuous).fill(Theme.surface.opacity(0.72)))
                .overlay(Capsule(style: .continuous).stroke(Theme.coral.opacity(0.18), lineWidth: 0.7))
                .shadow(color: Color.black.opacity(scheme == .dark ? 0.4 : 0.12), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
        .accessibilityAddTraits(.isStaticText)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension View {
    @ViewBuilder func glassy() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(Theme.coral.opacity(0.10)),
                             in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        } else {
            self.background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        #else
        self.background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        #endif
    }

    @ViewBuilder func glassPanelCompat(cornerRadius: CGFloat = Theme.Radius.pill) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule(style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(Theme.border.opacity(0.7), lineWidth: 0.7))
        }
        #else
        self.background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(Theme.border.opacity(0.7), lineWidth: 0.7))
        #endif
    }
}

let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()
