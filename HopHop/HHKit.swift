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

// MARK: - Links in text

/// The text with every web address in it made clickable.
func hhLinkified(_ text: String) -> AttributedString {
    var result = AttributedString(text)
    hhAddLinks(to: &result)
    return result
}

/// Makes every web address in already drawn text clickable.
func hhAddLinks(to result: inout AttributedString) {
    let text = String(result.characters)
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
    let whole = NSRange(text.startIndex..., in: text)
    for match in detector.matches(in: text, range: whole) {
        guard let url = match.url,
              let range = Range(match.range, in: text),
              let target = Range(range, in: result) else { continue }
        result[target].link = url
        result[target].foregroundColor = HH.primary
        result[target].underlineStyle = .single
    }
}

/// A title that opens a web page, underlined while the pointer is over it.
struct HHLinkTitle: View {
    let text: String
    let url: String
    let font: Font
    @Environment(\.openURL) private var openURL
    @State private var hovering = false

    var body: some View {
        Button {
            if let target = URL(string: url) { openURL(target) }
        } label: {
            // the arrow tells you the title is a link that leaves the app
            (Text(text) + Text(" ") + Text(Image(systemName: "arrow.up.right")).font(.system(size: 11, weight: .bold)))
                .font(font)
                .foregroundStyle(hovering ? HH.primary : HH.ink)
                .underline(hovering)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help(url)
        .accessibilityLabel("\(text), open job posting")
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

/// A small solid circle that keeps its colour inside a menu, where system symbols are drawn in grey.
func hhColorDot(_ color: Color, size: CGFloat = 12) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        NSColor(color).setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
        return true
    }
    image.isTemplate = false
    return image
}

/// A box that opens a list to pick from. Each entry can carry a colour dot, in the box and in the list.
struct HHDropdown<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: String
        var color: Color?
    }

    let label: String
    @Binding var selection: Value
    let options: [Option]

    private var current: Option? { options.first { $0.value == selection } }

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.title) { option in
                    if let color = option.color {
                        Label { Text(option.title) } icon: { Image(nsImage: hhColorDot(color)) }
                            .tag(option.value)
                    } else {
                        Text(option.title).tag(option.value)
                    }
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 8) {
                if let color = current?.color {
                    Circle().fill(color).frame(width: 9, height: 9)
                }
                Text(current?.title ?? "Choose")
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .font(HH.font(13, .medium))
            .foregroundStyle(HH.ink)
            .padding(.horizontal, 12)
            .frame(minWidth: 170, minHeight: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(HH.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(HH.borderStrong, lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("\(label): \(current?.title ?? "none")")
    }
}

/// A short list of choices as chips, or a dropdown once there are more than three.
struct HHChoice<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: String
        var color: Color?
    }

    let label: String
    @Binding var selection: Value
    let options: [Option]
    /// False when the caller already shows the label, for example in a settings row.
    var showsLabel = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsLabel { HHLabel(text: label) }
            if options.count > 3 {
                HHDropdown(
                    label: label,
                    selection: $selection,
                    options: options.map { .init(value: $0.value, title: $0.title, color: $0.color) }
                )
            } else {
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
    /// False sizes the dialog to its content, and scrolls only when the content is taller than the window.
    var scrolls = true
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    @State private var contentHeight: CGFloat?

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

            if scrolls {
                ScrollView {
                    content
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView {
                    content
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                .frame(maxHeight: contentHeight ?? .infinity)
            }

            Rectangle().fill(HH.border).frame(height: 1)

            HStack(spacing: 10) { footer }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: width)
        .frame(maxHeight: 700)
        // the shadow belongs to the panel's own shape, not to every control inside it
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(HH.surface)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(HH.border, lineWidth: 1))
        .padding(24)
    }
}
