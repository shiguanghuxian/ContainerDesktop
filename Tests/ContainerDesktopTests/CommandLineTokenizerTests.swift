import Testing
@testable import ContainerDesktop

@Suite("Command line tokenizer")
struct CommandLineTokenizerTests {
    @Test("splits whitespace and quoted arguments")
    func splitsQuotedArguments() throws {
        let arguments = try CommandLineTokenizer.split("sh -c \"echo hello world\"")

        #expect(arguments == ["sh", "-c", "echo hello world"])
    }

    @Test("keeps empty quoted arguments")
    func keepsEmptyQuotedArguments() throws {
        let arguments = try CommandLineTokenizer.split("printf ''")

        #expect(arguments == ["printf", ""])
    }

    @Test("throws for unterminated quotes")
    func throwsForUnterminatedQuotes() {
        #expect(throws: CommandLineTokenizerError.unterminatedQuote("\"")) {
            _ = try CommandLineTokenizer.split("sh -c \"echo")
        }
    }
}
