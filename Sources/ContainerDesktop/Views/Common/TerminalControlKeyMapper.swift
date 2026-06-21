import AppKit

enum TerminalControlKeyMapper {
    static let interruptByte: UInt8 = 0x03

    static func controlBytes(for event: NSEvent) -> [UInt8]? {
        guard event.type == .keyDown else { return nil }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.contains(.control),
              !flags.contains(.command),
              !flags.contains(.option)
        else {
            return nil
        }

        guard let characters = event.charactersIgnoringModifiers,
              characters.unicodeScalars.count == 1,
              let scalar = characters.unicodeScalars.first,
              scalar.isASCII
        else {
            return nil
        }

        let byte = UInt8(scalar.value)
        switch byte {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"):
            return [byte - 0x40]
        case UInt8(ascii: "a")...UInt8(ascii: "z"):
            return [byte - 0x60]
        case UInt8(ascii: "@"), UInt8(ascii: " "):
            return [0x00]
        case UInt8(ascii: "["):
            return [0x1B]
        case UInt8(ascii: "\\"):
            return [0x1C]
        case UInt8(ascii: "]"):
            return [0x1D]
        case UInt8(ascii: "^"), UInt8(ascii: "6"):
            return [0x1E]
        case UInt8(ascii: "_"):
            return [0x1F]
        case UInt8(ascii: "?"):
            return [0x7F]
        default:
            return nil
        }
    }

    static func isInterrupt(_ event: NSEvent) -> Bool {
        controlBytes(for: event) == [interruptByte]
    }
}
