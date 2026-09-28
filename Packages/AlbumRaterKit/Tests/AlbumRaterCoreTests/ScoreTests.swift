import Foundation
import Testing
@testable import AlbumRaterCore

@Suite("Notas de 1 a 10 con un decimal")
struct ScoreTests {
    @Test("Acepta coma o punto y espacios en los extremos", arguments: [
        ("9", 90), ("8,5", 85), ("8.5", 85), (" 7 ", 70), ("1", 10), ("10", 100),
        ("10,0", 100), ("9.9", 99), ("01", 10), ("1,0", 10),
    ])
    func parsesValidScores(text: String, tenths: Int) {
        #expect(Score(parsing: text)?.tenths == tenths)
    }

    @Test("Rechaza fuera de rango, más de un decimal o texto no numérico", arguments: [
        "", " ", "0", "0,9", "10,1", "11", "100", "8,55", "8,", ",5", ".", "abc", "-5", "+5",
        "8 5", "٣", "1e1", "8.5.1", "8,5,1",
    ])
    func rejectsInvalidScores(text: String) {
        #expect(Score(parsing: text) == nil)
    }

    @Test("Solo existen notas entre 1,0 y 10,0", arguments: [9, 10, 55, 100, 101])
    func tenthsRange(tenths: Int) {
        #expect((Score(tenths: tenths) != nil) == (10...100).contains(tenths))
    }

    @Test func exactValues() {
        let score = Score(8.5)
        #expect(score.value == 8.5)
        #expect(score.decimalValue == Decimal(string: "8.5"))
        #expect(Score(9.1).decimalValue == Decimal(string: "9.1"), "Decimal evita el error de 0,1 en Double")
    }

    @Test func formatsWithAtMostOneDecimal() {
        #expect(Score(9).formatted == 9.0.formatted(.number.precision(.fractionLength(0...1))))
        #expect(Score(8.5).formatted == 8.5.formatted(.number.precision(.fractionLength(0...1))))
        #expect(Score(parsing: Score(8.5).formatted) == Score(8.5), "lo que se muestra se puede volver a leer")
    }

    @Test func ordersByValue() {
        #expect(Score(7.5) < Score(8))
        #expect([Score(9), Score(1), Score(5.5)].sorted() == [Score(1), Score(5.5), Score(9)])
    }

    @Test("Decodifica el numeric de PostgreSQL", arguments: [("8.3", 83), ("10", 100), ("1.0", 10)])
    func decodes(json: String, tenths: Int) throws {
        #expect(try JSONDecoder().decode(Score.self, from: Data(json.utf8)).tenths == tenths)
    }

    @Test("Rechaza notas imposibles del servidor", arguments: ["0", "10.5", "-1"])
    func rejectsOutOfRangeJSON(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Score.self, from: Data(json.utf8))
        }
    }
}
