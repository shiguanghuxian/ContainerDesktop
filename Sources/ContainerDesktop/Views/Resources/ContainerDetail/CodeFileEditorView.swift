import AppKit
import CodeEditorView
import LanguageSupport
import SwiftUI

enum CodeFileEditorLanguage: Equatable, Sendable {
    case plainText
    case bash
    case c
    case cpp
    case css
    case dockerfile
    case go
    case goMod
    case html
    case java
    case javascript
    case jsx
    case json
    case kotlin
    case markdown
    case php
    case python
    case ruby
    case rust
    case scala
    case sql
    case swift
    case toml
    case tsx
    case typescript
    case yaml

    var languageConfiguration: LanguageConfiguration {
        CodeFileEditorLanguageConfiguration.configuration(for: self)
    }

    private static let extensionMap: [String: CodeFileEditorLanguage] = [
        "bash": .bash,
        "c": .c,
        "cc": .cpp,
        "cpp": .cpp,
        "c++": .cpp,
        "cjs": .javascript,
        "css": .css,
        "env": .bash,
        "go": .go,
        "h": .c,
        "hpp": .cpp,
        "htm": .html,
        "html": .html,
        "java": .java,
        "js": .javascript,
        "json": .json,
        "jsx": .jsx,
        "kt": .kotlin,
        "kts": .kotlin,
        "mjs": .javascript,
        "md": .markdown,
        "mkd": .markdown,
        "markdown": .markdown,
        "mod": .goMod,
        "php": .php,
        "properties": .plainText,
        "py": .python,
        "rb": .ruby,
        "rs": .rust,
        "scala": .scala,
        "sc": .scala,
        "sh": .bash,
        "sql": .sql,
        "swift": .swift,
        "toml": .toml,
        "ts": .typescript,
        "tsx": .tsx,
        "txt": .plainText,
        "xml": .html,
        "yaml": .yaml,
        "yml": .yaml,
        "zsh": .bash,
    ]

    private static let fileNameMap: [String: CodeFileEditorLanguage] = [
        ".bash_profile": .bash,
        ".bashrc": .bash,
        ".env": .bash,
        ".profile": .bash,
        ".zprofile": .bash,
        ".zshrc": .bash,
        "compose.yaml": .yaml,
        "compose.yml": .yaml,
        "docker-compose.yaml": .yaml,
        "docker-compose.yml": .yaml,
        "dockerfile": .dockerfile,
        "go.mod": .goMod,
        "makefile": .plainText,
        "podfile": .ruby,
        "rakefile": .ruby,
    ]

    static func language(for pathOrFileName: String?) -> CodeFileEditorLanguage {
        guard let value = pathOrFileName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return .plainText
        }

        let fileName = URL(fileURLWithPath: value).lastPathComponent
        let lowercasedFileName = fileName.lowercased()

        if let language = fileNameMap[lowercasedFileName] {
            return language
        }

        if lowercasedFileName.hasPrefix("dockerfile.") {
            return .dockerfile
        }

        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        guard !fileExtension.isEmpty else { return .plainText }
        return extensionMap[fileExtension] ?? .plainText
    }
}

struct CodeFileEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    var fileName: String?
    var isEditable: Bool
    var fontSize: CGFloat
    var wrapsLines = false

    @State private var position = CodeEditor.Position()
    @State private var messages = Set<TextLocated<Message>>()

    private var language: CodeFileEditorLanguage {
        CodeFileEditorLanguage.language(for: fileName)
    }

    var body: some View {
        CodeEditor(
            text: $text,
            position: $position,
            messages: $messages,
            language: language.languageConfiguration
        )
        .environment(
            \.codeEditorTheme,
            CodeFileEditorTheme.theme(
                for: colorScheme,
                fontSize: CodePreviewFontSize.clamped(fontSize)
            )
        )
        .environment(
            \.codeEditorLayoutConfiguration,
            CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: wrapsLines)
        )
        .environment(
            \.codeEditorIndentationConfiguration,
            CodeEditor.IndentationConfiguration(
                preference: .preferSpaces,
                tabWidth: 4,
                indentWidth: 4,
                tabKey: .identsInWhitespace,
                indentOnReturn: true
            )
        )
        .background(CodeFileEditorEditabilityBridge(isEditable: isEditable))
    }
}

private struct CodeFileEditorEditabilityBridge: NSViewRepresentable {
    var isEditable: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        syncEditability(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        syncEditability(from: nsView)
    }

    private func syncEditability(from markerView: NSView) {
        DispatchQueue.main.async {
            let rootView = markerView.nearestEditorContainer ?? markerView.window?.contentView
            rootView?.applyCodeEditorEditability(isEditable)
        }
    }
}

private extension NSView {
    var nearestEditorContainer: NSView? {
        var current: NSView? = superview
        while let view = current {
            if view.subviews.contains(where: { $0.containsCodeEditorTextView }) {
                return view
            }
            current = view.superview
        }
        return superview
    }

    var containsCodeEditorTextView: Bool {
        if isCodeEditorTextView { return true }
        return subviews.contains(where: \.containsCodeEditorTextView)
    }

    var isCodeEditorTextView: Bool {
        String(reflecting: type(of: self)).contains("CodeEditorView.CodeView")
    }

    func applyCodeEditorEditability(_ isEditable: Bool) {
        if isCodeEditorTextView, let text = self as? NSText {
            text.isEditable = isEditable
            text.isSelectable = true
        }

        for subview in subviews {
            subview.applyCodeEditorEditability(isEditable)
        }
    }
}

enum CodeFileEditorTheme {
    static func theme(for colorScheme: ColorScheme, fontSize: CGFloat) -> Theme {
        switch colorScheme {
        case .dark:
            Theme(
                colourScheme: .dark,
                fontName: "SFMono-Regular",
                fontSize: fontSize,
                textColour: NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.95, alpha: 1),
                commentColour: NSColor(calibratedRed: 0.46, green: 0.56, blue: 0.67, alpha: 1),
                stringColour: NSColor(calibratedRed: 0.94, green: 0.62, blue: 0.46, alpha: 1),
                characterColour: NSColor(calibratedRed: 0.94, green: 0.76, blue: 0.45, alpha: 1),
                numberColour: NSColor(calibratedRed: 0.74, green: 0.82, blue: 0.54, alpha: 1),
                identifierColour: NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.91, alpha: 1),
                operatorColour: NSColor(calibratedRed: 0.70, green: 0.78, blue: 0.88, alpha: 1),
                keywordColour: NSColor(calibratedRed: 0.58, green: 0.74, blue: 1.00, alpha: 1),
                symbolColour: NSColor(calibratedRed: 0.74, green: 0.80, blue: 0.88, alpha: 1),
                typeColour: NSColor(calibratedRed: 0.38, green: 0.84, blue: 0.92, alpha: 1),
                fieldColour: NSColor(calibratedRed: 0.69, green: 0.80, blue: 1.00, alpha: 1),
                caseColour: NSColor(calibratedRed: 0.82, green: 0.68, blue: 1.00, alpha: 1),
                backgroundColour: NSColor(calibratedRed: 0.045, green: 0.070, blue: 0.105, alpha: 1),
                currentLineColour: NSColor(calibratedRed: 0.075, green: 0.110, blue: 0.160, alpha: 1),
                selectionColour: NSColor(calibratedRed: 0.18, green: 0.35, blue: 0.58, alpha: 1),
                cursorColour: .white,
                invisiblesColour: NSColor(calibratedRed: 0.32, green: 0.42, blue: 0.54, alpha: 1)
            )
        default:
            Theme(
                colourScheme: .light,
                fontName: "SFMono-Regular",
                fontSize: fontSize,
                textColour: NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 1),
                commentColour: NSColor(calibratedRed: 0.41, green: 0.49, blue: 0.57, alpha: 1),
                stringColour: NSColor(calibratedRed: 0.70, green: 0.22, blue: 0.13, alpha: 1),
                characterColour: NSColor(calibratedRed: 0.66, green: 0.36, blue: 0.04, alpha: 1),
                numberColour: NSColor(calibratedRed: 0.18, green: 0.38, blue: 0.70, alpha: 1),
                identifierColour: NSColor(calibratedRed: 0.15, green: 0.25, blue: 0.34, alpha: 1),
                operatorColour: NSColor(calibratedRed: 0.24, green: 0.22, blue: 0.40, alpha: 1),
                keywordColour: NSColor(calibratedRed: 0.40, green: 0.27, blue: 0.74, alpha: 1),
                symbolColour: NSColor(calibratedRed: 0.25, green: 0.23, blue: 0.44, alpha: 1),
                typeColour: NSColor(calibratedRed: 0.02, green: 0.34, blue: 0.48, alpha: 1),
                fieldColour: NSColor(calibratedRed: 0.31, green: 0.32, blue: 0.64, alpha: 1),
                caseColour: NSColor(calibratedRed: 0.44, green: 0.29, blue: 0.72, alpha: 1),
                backgroundColour: NSColor(calibratedRed: 0.985, green: 0.994, blue: 1.000, alpha: 1),
                currentLineColour: NSColor(calibratedRed: 0.925, green: 0.968, blue: 1.000, alpha: 1),
                selectionColour: NSColor(calibratedRed: 0.72, green: 0.84, blue: 1.00, alpha: 1),
                cursorColour: .black,
                invisiblesColour: NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.86, alpha: 1)
            )
        }
    }
}

private enum CodeFileEditorLanguageConfiguration {
    private static let stringPattern = #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#
    private static let characterPattern = #"'(?:\\.|[^'\\])'"#
    private static let numberPattern = #"\b(?:0x[0-9A-Fa-f_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d[\d_]*)?)\b"#
    private static let identifierPattern = #"[A-Za-z_][A-Za-z0-9_]*"#
    private static let shellIdentifierPattern = #"[A-Za-z_][A-Za-z0-9_-]*"#

    static func configuration(for language: CodeFileEditorLanguage) -> LanguageConfiguration {
        switch language {
        case .plainText:
            .none
        case .bash:
            shell(name: "Shell")
        case .c:
            cLike(name: "C", keywords: cKeywords)
        case .cpp:
            cLike(name: "C++", keywords: cppKeywords)
        case .css:
            style(name: "CSS")
        case .dockerfile:
            shell(name: "Dockerfile", keywords: dockerfileKeywords, caseInsensitive: true)
        case .go:
            cLike(name: "Go", keywords: goKeywords)
        case .goMod:
            simple(name: "Go Module", singleLineComment: "//", keywords: ["module", "go", "require", "replace", "exclude", "retract"])
        case .html:
            markup(name: "HTML")
        case .java:
            cLike(name: "Java", keywords: javaKeywords)
        case .javascript:
            cLike(name: "JavaScript", keywords: javascriptKeywords)
        case .jsx:
            cLike(name: "JSX", keywords: javascriptKeywords)
        case .json:
            data(name: "JSON")
        case .kotlin:
            cLike(name: "Kotlin", keywords: kotlinKeywords)
        case .markdown:
            simple(name: "Markdown", singleLineComment: nil, keywords: [])
        case .php:
            cLike(name: "PHP", keywords: phpKeywords)
        case .python:
            simple(name: "Python", singleLineComment: "#", keywords: pythonKeywords)
        case .ruby:
            simple(name: "Ruby", singleLineComment: "#", keywords: rubyKeywords)
        case .rust:
            cLike(name: "Rust", keywords: rustKeywords)
        case .scala:
            cLike(name: "Scala", keywords: scalaKeywords)
        case .sql:
            .sqlite()
        case .swift:
            .swift()
        case .toml:
            simple(name: "TOML", singleLineComment: "#", keywords: ["true", "false"])
        case .tsx:
            cLike(name: "TSX", keywords: typescriptKeywords)
        case .typescript:
            cLike(name: "TypeScript", keywords: typescriptKeywords)
        case .yaml:
            simple(name: "YAML", singleLineComment: "#", keywords: ["true", "false", "null", "yes", "no", "on", "off"])
        }
    }

    private static func cLike(name: String, keywords: [String]) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: regex(stringPattern),
            characterRegex: regex(characterPattern),
            numberRegex: regex(numberPattern),
            singleLineComment: "//",
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: regex(identifierPattern),
            operatorRegex: nil,
            reservedIdentifiers: keywords,
            reservedOperators: []
        )
    }

    private static func shell(
        name: String,
        keywords: [String] = shellKeywords,
        caseInsensitive: Bool = false
    ) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            caseInsensitiveReservedIdentifiers: caseInsensitive,
            stringRegex: regex(stringPattern),
            characterRegex: nil,
            numberRegex: regex(numberPattern),
            singleLineComment: "#",
            nestedComment: nil,
            identifierRegex: regex(shellIdentifierPattern),
            operatorRegex: nil,
            reservedIdentifiers: keywords,
            reservedOperators: []
        )
    }

    private static func simple(name: String, singleLineComment: String?, keywords: [String]) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: regex(stringPattern),
            characterRegex: regex(characterPattern),
            numberRegex: regex(numberPattern),
            singleLineComment: singleLineComment,
            nestedComment: nil,
            identifierRegex: regex(identifierPattern),
            operatorRegex: nil,
            reservedIdentifiers: keywords,
            reservedOperators: []
        )
    }

    private static func data(name: String) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: regex(#""(?:\\.|[^"\\])*""#),
            characterRegex: nil,
            numberRegex: regex(numberPattern),
            singleLineComment: nil,
            nestedComment: nil,
            identifierRegex: regex(identifierPattern),
            operatorRegex: nil,
            reservedIdentifiers: ["true", "false", "null"],
            reservedOperators: []
        )
    }

    private static func markup(name: String) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: regex(stringPattern),
            characterRegex: nil,
            numberRegex: regex(numberPattern),
            singleLineComment: nil,
            nestedComment: (open: "<!--", close: "-->"),
            identifierRegex: regex(#"[:A-Za-z_][-:A-Za-z0-9_]*"#),
            operatorRegex: nil,
            reservedIdentifiers: htmlKeywords,
            reservedOperators: []
        )
    }

    private static func style(name: String) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: regex(stringPattern),
            characterRegex: nil,
            numberRegex: regex(numberPattern),
            singleLineComment: nil,
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: regex(#"[-A-Za-z_][-A-Za-z0-9_]*"#),
            operatorRegex: nil,
            reservedIdentifiers: cssKeywords,
            reservedOperators: []
        )
    }

    private static func regex(_ pattern: String) -> Regex<Substring>? {
        try? Regex<Substring>(pattern, as: Substring.self)
    }

    private static let shellKeywords = [
        "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac",
        "function", "in", "select", "time", "coproc", "return", "exit", "export", "local", "readonly",
        "declare", "typeset", "unset", "shift", "break", "continue", "trap", "source", "alias", "eval",
    ]

    private static let dockerfileKeywords = [
        "ADD", "ARG", "CMD", "COPY", "ENTRYPOINT", "ENV", "EXPOSE", "FROM", "HEALTHCHECK", "LABEL",
        "MAINTAINER", "ONBUILD", "RUN", "SHELL", "STOPSIGNAL", "USER", "VOLUME", "WORKDIR",
    ]

    private static let cKeywords = [
        "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else",
        "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register",
        "restrict", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef",
        "union", "unsigned", "void", "volatile", "while",
    ]

    private static let cppKeywords = cKeywords + [
        "alignas", "alignof", "and", "asm", "bitand", "bitor", "bool", "catch", "class", "concept",
        "const_cast", "constexpr", "decltype", "delete", "dynamic_cast", "explicit", "export", "false",
        "friend", "mutable", "namespace", "new", "noexcept", "nullptr", "operator", "or", "private",
        "protected", "public", "reinterpret_cast", "requires", "static_assert", "static_cast", "template",
        "this", "thread_local", "throw", "true", "try", "typename", "using", "virtual", "xor",
    ]

    private static let goKeywords = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough",
        "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range",
        "return", "select", "struct", "switch", "type", "var", "true", "false", "nil", "iota",
    ]

    private static let javaKeywords = [
        "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const",
        "continue", "default", "do", "double", "else", "enum", "extends", "final", "finally", "float",
        "for", "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native",
        "new", "package", "private", "protected", "public", "return", "short", "static", "strictfp",
        "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "void",
        "volatile", "while", "true", "false", "null",
    ]

    private static let javascriptKeywords = [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default",
        "delete", "do", "else", "export", "extends", "false", "finally", "for", "from", "function",
        "if", "import", "in", "instanceof", "let", "new", "null", "of", "return", "static", "super",
        "switch", "this", "throw", "true", "try", "typeof", "undefined", "var", "void", "while", "yield",
    ]

    private static let typescriptKeywords = javascriptKeywords + [
        "abstract", "any", "as", "asserts", "boolean", "declare", "enum", "implements", "infer",
        "interface", "is", "keyof", "module", "namespace", "never", "number", "private", "protected",
        "public", "readonly", "require", "string", "symbol", "type", "unknown",
    ]

    private static let kotlinKeywords = [
        "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in",
        "interface", "is", "null", "object", "package", "return", "super", "this", "throw", "true",
        "try", "typealias", "typeof", "val", "var", "when", "while", "by", "catch", "constructor",
        "delegate", "dynamic", "field", "file", "finally", "get", "import", "init", "param", "property",
        "receiver", "set", "setparam", "where", "actual", "abstract", "annotation", "companion", "const",
        "crossinline", "data", "enum", "expect", "external", "final", "infix", "inline", "inner",
        "internal", "lateinit", "noinline", "open", "operator", "out", "override", "private",
        "protected", "public", "reified", "sealed", "suspend", "tailrec", "vararg",
    ]

    private static let pythonKeywords = [
        "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue",
        "def", "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import",
        "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while",
        "with", "yield",
    ]

    private static let rubyKeywords = [
        "BEGIN", "END", "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do",
        "else", "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not",
        "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true", "undef", "unless",
        "until", "when", "while", "yield",
    ]

    private static let rustKeywords = [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
        "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
        "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe",
        "use", "where", "while",
    ]

    private static let scalaKeywords = [
        "abstract", "case", "catch", "class", "def", "do", "else", "extends", "false", "final", "finally",
        "for", "forSome", "if", "implicit", "import", "lazy", "match", "new", "null", "object", "override",
        "package", "private", "protected", "return", "sealed", "super", "this", "throw", "trait", "try",
        "true", "type", "val", "var", "while", "with", "yield",
    ]

    private static let phpKeywords = [
        "__halt_compiler", "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class",
        "clone", "const", "continue", "declare", "default", "die", "do", "echo", "else", "elseif", "empty",
        "enddeclare", "endfor", "endforeach", "endif", "endswitch", "endwhile", "eval", "exit", "extends",
        "final", "finally", "fn", "for", "foreach", "function", "global", "goto", "if", "implements",
        "include", "include_once", "instanceof", "insteadof", "interface", "isset", "list", "match",
        "namespace", "new", "or", "print", "private", "protected", "public", "readonly", "require",
        "require_once", "return", "static", "switch", "throw", "trait", "try", "unset", "use", "var",
        "while", "xor", "yield", "true", "false", "null",
    ]

    private static let htmlKeywords = [
        "a", "article", "aside", "body", "button", "canvas", "div", "footer", "form", "h1", "h2", "h3",
        "head", "header", "html", "img", "input", "label", "li", "link", "main", "meta", "nav", "ol",
        "option", "p", "script", "section", "select", "span", "style", "table", "tbody", "td", "textarea",
        "th", "thead", "title", "tr", "ul",
    ]

    private static let cssKeywords = [
        "align-items", "animation", "background", "border", "bottom", "color", "display", "flex", "font",
        "gap", "grid", "height", "justify-content", "left", "margin", "padding", "position", "right",
        "top", "transform", "transition", "width", "z-index", "absolute", "block", "fixed", "grid",
        "inline", "none", "relative", "solid", "sticky",
    ]
}
