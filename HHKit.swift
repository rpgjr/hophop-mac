import SwiftUI

// MARK: - Surfaces

extension View {
    /// A flat white card with a thin border and a soft shadow.
    func hhCard(radius: CGFloat = 12, fill: Color = HH.surface) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(HH.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    func hhSunken(radius: CGFloat = 10) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius).fill(HH.sunken))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(HH.border, lineWidth: 1))
    }
}

// MARK: - Buttons

struct HHButtonStyle: ButtonStyle {
    enum Kind { case plain, primary, secondary, danger }

    var kind: Kind = .plain
    var small = false
    var square = false

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind, small: small, square: square)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let small: Bool
        let square: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        private var fill: Color {
            switch kind {
            case .plain, .danger: HH.surface
            case .primary: HH.primary
            case .secondary: HH.primarySoft
            }
        }

        private var text: Color {
            switch kind {
            case .plain: HH.ink
            case .primary: HH.onPrimary
            case .secondary: HH.primaryInk
            case .danger: HH.danger
            }
        }

        private var stroke: Color {
            switch kind {
            case .plain, .danger: HH.borderStrong
            case .primary: HH.primary
            case .secondary: .clear
            }
        }

        var body: some View {
            let height: CGFloat = small ? 30 : 36

            configuration.label
                .font(HH.font(small ? 13 : 14, .medium))
                .foregroundStyle(text)
                .padding(.horizontal, square ? 0 : (small ? 10 : 14))
                .frame(width: square ? 34 : nil, height: height)
                .background(RoundedRectangle(cornerRadius: 8).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(hovering && isEnabled ? 0.06 : 0))
                )
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(stroke, lineWidth: 1))
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
                .contentShape(.rect(cornerRadius: 8))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

extension ButtonStyle where Self == HHButtonStyle {
    static var hh: HHButtonStyle { HHButtonStyle() }
    static func hh(_ kind: HHButtonStyle.Kind, small: Bool = false, square: Bool = false) -> HHButtonStyle {
        HHButtonStyle(kind: kind, small: small, square: square)
    }
}

// MARK: - Labels, notices, spinner

struct HHLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(HH.font(13, .medium))
            .foregroundStyle(HH.muted)
    }
}

struct HHSpinner: View {
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(HH.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
            .accessibilityLabel("Loading")
    }
}

struct HHNotice: View {
    enum Tone { case ok, warn, error, info }

    let tone: Tone
    let text: String

    private var fill: Color {
        switch tone {
        case .ok: HH.primarySoft
        case .warn: HH.warnSoft
        case .error: HH.dangerSoft
        case .info: HH.sunken
        }
    }

    private var ink: Color {
        switch tone {
        case .ok: HH.primaryInk
        case .warn: HH.warnInk
        case .error: HH.danger
        case .info: HH.ink
        }
    }

    var body: some View {
        Text(text)
            .font(HH.font(13, .medium))
            .foregroundStyle(ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(fill))
    }
}

// MARK: - Inputs

struct HHTextField: View {
    let label: String
    @Binding var text: String
    var prompt = ""
    var mono = false
    var hint: String?
    var onSubmit: (() -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HHLabel(text: label)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(HH.muted.opacity(0.65)))
                .textFieldStyle(.plain)
                .font(mono ? HH.mono(13) : HH.font(14))
                .foregroundStyle(HH.ink)
                .focused($focused)
                .onSubmit { onSubmit?() }
                .modifier(HHInputBox(focused: focused))
                .accessibilityLabel(label)
            if let hint {
                Text(hint)
                    .font(HH.font(12, .medium))
                    .foregroundStyle(HH.danger)
            }
        }
    }
}

struct HHNumberField: View {
    let label: String
    @Binding var value: Double?
    var prompt = "Optional"
    var hint: String?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HHLabel(text: label)
            TextField("", value: $value, format: .number, prompt: Text(prompt).foregroundStyle(HH.muted.opacity(0.65)))
                .textFieldStyle(.plain)
                .font(HH.font(14))
                .monospacedDigit()
                .foregroundStyle(HH.ink)
                .focused($focused)
                .modifier(HHInputBox(focused: focused))
                .accessibilityLabel(label)
            if let hint {
                Text(hint)
                    .font(HH.font(12, .medium))
                    .foregroundStyle(HH.danger)
            }
        }
    }
}

struct HHTextArea: View {
    let label: String
    @Binding var text: String
    var height: CGFloat = 84

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HHLabel(text: label)
            TextEditor(text: $text)
                .font(HH.font(14))
                .foregroundStyle(HH.ink)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .frame(height: height)
                .modifier(HHInputBox(focused: focused, vertical: 6))
                .accessibilityLabel(label)
        }
    }
}

struct HHInputBox: ViewModifier {
    let focused: Bool
    var vertical: CGFloat = 9

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, vertical)
            .background(RoundedRectangle(cornerRadius: 8).fill(HH.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focused ? HH.primary : HH.borderStrong, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(HH.primary.opacity(focused ? 0.25 : 0), lineWidth: 3)
                    .padding(-2)
            )
    }
}

// MARK: - Chips and choices

struct HHChip: View {
    let title: String
    var color: Color?
    var on = false
    var icon: String?
    /// A read-only label, like a tag, instead of something to press.
    var tag = false

    var body: some View {
        HStack(spacing: 6) {
            if let color {
                Circle().fill(color).frame(width: 9, height: 9)
            }
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            }
            Text(title)
        }
        .font(HH.font(tag ? 12 : 13, .medium))
        .foregroundStyle(on ? HH.primaryInk : (tag ? HH.muted : HH.ink))
        .padding(.horizontal, 12)
        .frame(height: tag ? 26 : 30)
        .background(Capsule().fill(on ? HH.primarySoft : (tag ? HH.sunken : HH.surface)))
        .overlay(Capsule().stroke(on ? HH.primary : (tag ? HH.border : HH.borderStrong), lineWidth: 1))
        .fixedSize()
    }
}

/// A wrapping row of chips where exactly one is on.
struct HHChoice<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: String
        var color: Color?
    }

    let label: String
    @Binding var selection: Value
    let options: [Option]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HHLabel(text: label)
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.title) { option in
                    Button {
                        selection = option.value
                    } label: {
                        HHChip(title: option.title, color: option.color, on: selection == option.value)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option.value ? .isSelected : [])
                }
            }
        }
    }
}

/// Lays children out left to right and wraps them onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (origins, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Modal

/// The dialog card shown over a dimmed page, instead of a system sheet.
struct HHModal<Content: View, Footer: View>: View {
    @Environment(ApplicationStore.self) private var store

    let title: String
    var subtitle: String?
    var width: CGFloat = 560
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(HH.display(18))
                        .foregroundStyle(HH.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(HH.font(13))
                            .foregroundStyle(HH.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    store.modal = nil
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.hh(.plain, square: true))
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Rectangle().fill(HH.border).frame(height: 1)

            ScrollView {
                content
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle().fill(HH.border).frame(height: 1)

            HStack(spacing: 10) { footer }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: width)
        .frame(maxHeight: 700)
        .background(RoundedRectangle(cornerRadius: 14).fill(HH.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(HH.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .padding(24)
    }
}
