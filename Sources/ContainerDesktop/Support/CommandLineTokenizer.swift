import Foundation

enum CommandLineTokenizerError: LocalizedError, Equatable {
    case unterminatedQuote(Character)

    var errorDescription: String? {
        switch self {
        case .unterminatedQuote(let quote):
            return "命令参数引号未闭合：\(quote)"
        }
    }
}

enum CommandLineTokenizer {
    static func split(_ input: String) throws -> [String] {
        var arguments: [String] = []
        var current = ""
        var activeQuote: Character?
        var isEscaping = false
        var hasToken = false

        for character in input {
            if isEscaping {
                current.append(character)
                isEscaping = false
                hasToken = true
                continue
            }

            if character == "\\" && activeQuote != "'" {
                isEscaping = true
                hasToken = true
                continue
            }

            if let quote = activeQuote {
                if character == quote {
                    activeQuote = nil
                } else {
                    current.append(character)
                    hasToken = true
                }
                continue
            }

            if character == "\"" || character == "'" {
                activeQuote = character
                hasToken = true
            } else if character.isWhitespace {
                if hasToken {
                    arguments.append(current)
                    current = ""
                    hasToken = false
                }
            } else {
                current.append(character)
                hasToken = true
            }
        }

        if isEscaping {
            current.append("\\")
        }

        if let activeQuote {
            throw CommandLineTokenizerError.unterminatedQuote(activeQuote)
        }

        if hasToken {
            arguments.append(current)
        }

        return arguments
    }
}
