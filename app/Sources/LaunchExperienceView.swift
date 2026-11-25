import SwiftUI

/// Branded launch moment drawn in SwiftUI after the app is already running.
/// It never delays initialization; it simply covers the first frame and dissolves.
struct LaunchExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var glow = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            SayoBackground(accent: Theme.rose)

            // A slow, soft halo behind the mark.
            Circle()
                .fill(
                    RadialGradient(colors: [Theme.coral.opacity(0.34), Theme.lilac.opacity(0.09), .clear],
                                   center: .center, startRadius: 2, endRadius: 190)
                )
                .frame(width: 380, height: 380)
                .scaleEffect(glow ? 1.08 : 0.86)
                .opacity(glow ? 0.95 : 0.55)
                .blur(radius: 10)

            // A hairline ribbon ring that gently turns.
            Circle()
                .trim(from: 0.03, to: 0.72)
                .stroke(
                    AngularGradient(colors: [Theme.coral.opacity(0), Theme.coral.opacity(0.55), Theme.peach.opacity(0.12), Theme.coral.opacity(0)],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
                .frame(width: 226, height: 226)
                .rotationEffect(.degrees(glow ? 360 : 0))
                .opacity(appeared ? 0.8 : 0)

            VStack(spacing: 22) {
                ZStack {
                    BrandMark(size: 104)
                        .shadow(color: Theme.rose.opacity(0.42), radius: 30, y: 14)
                    // A thin light sweep across the mark.
                    LinearGradient(colors: [.clear, Color.white.opacity(0.65), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 46, height: 150)
                        .rotationEffect(.degrees(24))
                        .offset(x: shimmer ? 120 : -120)
                        .mask(RoundedRectangle(cornerRadius: 31, style: .continuous).frame(width: 104, height: 104))
                        .allowsHitTesting(false)
                }
                .scaleEffect(appeared ? 1 : 0.72)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text("SayoSign")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .tracking(-1)
                        .foregroundStyle(Theme.gradient)
                    Text(L("Sign. Install. Create."))
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .tracking(1.6)
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                }
                .offset(y: appeared ? 0 : 10)
                .opacity(appeared ? 1 : 0)

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Theme.coral.opacity(0.7))
                            .frame(width: 4.5, height: 4.5)
                            .scaleEffect(glow ? 1 : 0.55)
                            .opacity(glow ? 1 : 0.35)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(i) * 0.14),
                                value: glow
                            )
                    }
                }
                .padding(.top, 2)
                .opacity(appeared ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.76)) { appeared = true }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { glow = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false).delay(0.3)) { shimmer = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SayoSign. " + L("On-device IPA signer"))
    }
}
