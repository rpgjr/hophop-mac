import SwiftUI

/// Job pages often hand over the description as HTML. This draws it with its paragraphs, bold
/// text and bullet lists, and gives the plain text for the edit box. Only a few tags are read,
/// so a page cannot inject anything.
enum HTMLText {
    static func looksLikeHTML(_ text: String) -> Bool {
        text.range(of: "</?[a-zA-Z][a-zA-Z0-9]*[^>]*>", options: .regularExpression) != nil
    }

    /// The description ready to show, with web addresses clickable.
    static func attributed(_ text: String) -> AttributedString {
        guard looksLikeHTML(text) else { return drawPlain(text) }
        var result = render(text)
        hhAddLinks(to: &result)
        return result
    }

    /// The text of an HTML description, for the edit box.
    static func plain(_ text: String) -> String {
        looksLikeHTML(text) ? String(render(text).characters) : formatPlain(text)
    }

    /// The edit box shows plain text, so keep the original HTML unless the user changed the text.
    static func keep(shown: String, original: String?) -> String? {
        let text = shown.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if let original, text == plain(original).trimmingCharacters(in: .whitespacesAndNewlines) { return original }
        return text
    }

    // MARK: - Descriptions that arrive as one flat block of text

    // Section titles job posts use. The strict group is distinctive enough to split at any word;
    // the loose group only counts after the end of a sentence.
    private static let strictHeadings = #"About (?:This Job|The Job|The Role|The Team|The Company|Us|You|[A-Z][A-Za-z0-9&.\-]*)|Job Summary|Position Summary|Key Responsibilities|Responsibilities|Qualifications|Minimum Qualifications|Preferred Qualifications|Requirements|Minimum Requirements|Required Skills|Nice to Have|What You(?:'|’)ll Do|What You Will Do|What We Offer|Who You Are|Why Join Us|Work Schedule"#
    private static let looseHeadings = "Summary|Overview|Duties|Skills|Benefits|Perks|Compensation|Education|Experience"

    private static let strictInText = try! NSRegularExpression(pattern: #"(^|[.!?:)\]]\s+|\s+)("# + strictHeadings + #")(?=\s+[A-Z])"#)
    private static let looseInText = try! NSRegularExpression(pattern: #"(^|[.!?:)\]]\s+)("# + looseHeadings + #")(?=\s+[A-Z])"#)
    private static let headingLine = try! NSRegularExpression(pattern: "^(?:" + strictHeadings + "|" + looseHeadings + ")$")
    private static let sentenceEnd = try! NSRegularExpression(pattern: #"(?<=[.!?])\s+(?=[A-Z0-9•])"#)

    static func isHeadingLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return headingLine.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
    }

    /// A flat text gets its section titles on their own line and its long runs split into short paragraphs.
    /// Text that already has its own line breaks is left as it is.
    static func formatPlain(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        guard !trimmed.isEmpty, Double(trimmed.count) / Double(max(lines, 1)) > 400 else { return text }

        func replace(_ regex: NSRegularExpression, in input: String) -> String {
            regex.stringByReplacingMatches(in: input, range: NSRange(input.startIndex..., in: input), withTemplate: "$1\n\n$2\n")
        }
        var result = replace(looseInText, in: replace(strictInText, in: trimmed))
        result = result.replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)

        let blocks = result.components(separatedBy: "\n").map { block -> String in
            guard block.count > 350 else { return block }
            var paragraphs: [String] = []
            var current = ""
            for sentence in split(block, by: sentenceEnd) {
                current = current.isEmpty ? sentence : current + " " + sentence
                if current.count >= 280 {
                    paragraphs.append(current)
                    current = ""
                }
            }
            if !current.isEmpty { paragraphs.append(current) }
            return paragraphs.joined(separator: "\n\n")
        }
        return blocks.joined(separator: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func split(_ text: String, by regex: NSRegularExpression) -> [String] {
        let whole = text as NSString
        var parts: [String] = []
        var start = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: whole.length)) {
            parts.append(whole.substring(with: NSRange(location: start, length: match.range.location - start)))
            start = match.range.location + match.range.length
        }
        parts.append(whole.substring(from: start))
        return parts
    }

    /// The flat text drawn as short paragraphs, with section titles in bold and web addresses clickable.
    private static func drawPlain(_ text: String) -> AttributedString {
        var out = AttributedString()
        let lines = formatPlain(text).components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            var run = AttributedString(line + (index < lines.count - 1 ? "\n" : ""))
            run.font = HH.font(14, isHeadingLine(line) ? .semibold : .regular)
            out.append(run)
        }
        hhAddLinks(to: &out)
        return out
    }

    // MARK: - Drawing

    private static let tagPattern = try! NSRegularExpression(pattern: "<(/?)([a-zA-Z0-9]+)[^>]*>")

    private static func render(_ html: String) -> AttributedString {
        var out = AttributedString()
        var bold = 0, italic = 0
        var lists: [(ordered: Bool, count: Int)] = []
        var bulletPending = false // a bullet was just drawn, so its text must stay on the same line
        var trailing = 99 // newlines at the end of what is drawn so far; starts high so nothing leads

        func append(_ piece: String) {
            guard !piece.isEmpty else { return }
            bulletPending = false
            var run = AttributedString(piece)
            var font = HH.font(14, bold > 0 ? .semibold : .regular)
            if italic > 0 { font = font.italic() }
            run.font = font
            out.append(run)
            let tail = piece.reversed().prefix { $0 == "\n" }.count
            trailing = tail == piece.count ? trailing + tail : tail
        }
        func lineBreaks(_ wanted: Int) {
            if bulletPending { return }
            let missing = wanted - trailing
            if missing > 0 { append(String(repeating: "\n", count: missing)) }
        }

        // a description cut short by the page reader can end inside a tag
        let html = html.replacingOccurrences(of: "<[^>]*$", with: "", options: .regularExpression)
        let whole = html as NSString
        var cursor = 0
        func text(_ raw: String) {
            var piece = decode(raw).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            if trailing > 0 || bulletPending { piece = String(piece.drop { $0 == " " }) }
            append(piece)
        }

        for match in tagPattern.matches(in: html, range: NSRange(location: 0, length: whole.length)) {
            text(whole.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length
            let closing = whole.substring(with: match.range(at: 1)) == "/"
            let name = whole.substring(with: match.range(at: 2)).lowercased()

            switch name {
            case "br": if trailing < 2 { append("\n") }
            case "p", "div", "section", "article":
                lineBreaks(name == "p" && lists.isEmpty ? 2 : 1) // list items stay tight
            case "h1", "h2", "h3", "h4", "h5", "h6":
                if closing { bold -= 1; lineBreaks(2) } else { lineBreaks(2); bold += 1 }
            case "strong", "b": bold += closing ? -1 : 1
            case "em", "i": italic += closing ? -1 : 1
            case "ul", "ol":
                if closing { _ = lists.popLast() } else { lists.append((name == "ol", 0)) }
                lineBreaks(1)
            case "li":
                lineBreaks(1)
                if !closing {
                    if var current = lists.popLast() {
                        current.count += 1
                        append(current.ordered ? "\(current.count). " : "• ")
                        lists.append(current)
                    } else {
                        append("• ")
                    }
                    trailing = 0
                    bulletPending = true
                }
            case "script", "style":
                // skip everything up to the closing tag
                let rest = NSRange(location: cursor, length: whole.length - cursor)
                let end = whole.range(of: "</\(name)", options: .caseInsensitive, range: rest)
                if !closing, end.location != NSNotFound { cursor = end.location }
            default: break
            }
        }
        text(whole.substring(from: cursor))

        // drop the blank lines left at the end
        while let last = out.characters.last, last == "\n" || last == " " {
            out.characters.removeLast()
        }
        return out
    }

    private static func decode(_ raw: String) -> String {
        var text = raw
        let named = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&ndash;": "–", "&mdash;": "—", "&bull;": "•"]
        for (entity, value) in named { text = text.replacingOccurrences(of: entity, with: value) }
        // numeric entities such as &#8217;
        while let found = text.range(of: "&#[0-9]+;", options: .regularExpression) {
            let digits = text[found].dropFirst(2).dropLast()
            let replacement = UInt32(digits).flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? ""
            text.replaceSubrange(found, with: replacement)
        }
        return text
    }
}
