import Foundation

enum TextValidation {
    // Lo mismo que [[:cntrl:]] en PostgreSQL: control (Cc) y separadores de línea/párrafo.
    // CharacterSet.controlCharacters también incluye los de formato (Cf) y rechazaría emoji como 👨‍💻.
    private static let forbidden: Set<Unicode.GeneralCategory> = [.control, .lineSeparator, .paragraphSeparator]

    /// Quita espacios de los extremos y comprueba longitud y ausencia de saltos de línea.
    /// PostgreSQL cuenta caracteres Unicode, no grupos visuales como un emoji compuesto.
    static func singleLine(_ text: String, length: ClosedRange<Int>) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard length.contains(text.unicodeScalars.count),
              !text.unicodeScalars.contains(where: { forbidden.contains($0.properties.generalCategory) }) else {
            return nil
        }
        return text
    }
}
