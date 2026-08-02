import SwiftUI

/// Renders a Markdown string into an AttributedString, falling back to plain text.
enum MarkdownRenderer {
    static func attributedString(for markdown: String) -> AttributedString {
        let clean = markdown.isEmpty ? " " : markdown
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(
                markdown: clean,
                options: options,
                baseURL: nil
            )
        } catch {
            return AttributedString(clean)
        }
    }
}
