import XCTest

/// Recorrido crítico de la app contra el Supabase local: crear cuenta, perfil, álbum y notas.
/// Necesita `supabase start` y las variables que rellena `scripts/test-ui.sh`.
final class CriticalFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["SUPABASE_TEST_URL"], let key = environment["SUPABASE_TEST_PUBLISHABLE_KEY"] else {
            throw XCTSkip("Sin Supabase local: ejecuta scripts/test-ui.sh")
        }
        app = XCUIApplication()
        app.launchEnvironment["ALBUM_RATER_UITEST_SUPABASE_URL"] = url
        app.launchEnvironment["ALBUM_RATER_UITEST_SUPABASE_KEY"] = key
        // Idioma fijo: la media se muestra con coma decimal.
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
    }

    func testSignUpCreateAlbumAndRateTracks() throws {
        signUp()
        createProfile()
        createAlbum(title: "OK Computer", artist: "Radiohead", tracks: ["Airbag", "Paranoid Android", "Subterranean"])

        let average = app.descendants(matching: .any)["album-average"]
        XCTAssertTrue(average.waitForExistence(timeout: 10))
        XCTAssertTrue(average.label.contains("–"), "sin notas no hay media: \(average.label)")

        rateTrack(1, score: "9", comment: "Gran comienzo")
        XCTAssertTrue(waitForLabel(of: average, containing: "9"), average.label)
        rateTrack(2, score: "8")
        XCTAssertTrue(waitForLabel(of: average, containing: "8,5"), "9 y 8 dan 8,5: \(average.label)")
        XCTAssertTrue(app.buttons["track-1"].label.contains("Gran comienzo"))

        // El historial muestra la misma media y cuántas canciones llevas.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let row = app.buttons["session-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("OK Computer"), row.label)
        XCTAssertTrue(row.label.contains("8,5"), row.label)
        XCTAssertTrue(row.label.contains("2/3"), row.label)

        signOut()
    }

    func testWrongPasswordShowsError() {
        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 15))
        email.tap()
        email.typeText("nadie-\(UUID().uuidString.prefix(8))@example.com")
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("contraseña-incorrecta")
        app.buttons["Log in"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Couldn't log in"))
            .firstMatch.waitForExistence(timeout: 10))
    }

    // MARK: - Pasos

    private func signUp() {
        let createAccount = app.buttons["Create an account"]
        XCTAssertTrue(createAccount.waitForExistence(timeout: 15))
        createAccount.tap()
        let password = "Prueba-\(UUID().uuidString.prefix(12))"
        type("test-\(UUID().uuidString.lowercased())@example.com", into: app.textFields["Email"])
        typeSecure(password, into: app.secureTextFields["Password"])
        typeSecure(password, into: app.secureTextFields["Repeat password"])
        app.buttons["Create account"].firstMatch.tap()
    }

    private func createProfile() {
        let displayName = app.textFields["Nombre visible"]
        XCTAssertTrue(displayName.waitForExistence(timeout: 15), "tras el alta se pide el perfil")
        type("Jaime 👨‍💻", into: displayName)
        type("ui_\(UUID().uuidString.lowercased().prefix(12).replacingOccurrences(of: "-", with: ""))",
             into: app.textFields["Nombre de usuario"])
        app.buttons["Guardar perfil"].tap()
        XCTAssertTrue(app.staticTexts["Tu historial empieza aquí"].waitForExistence(timeout: 15))
    }

    private func createAlbum(title: String, artist: String, tracks: [String]) {
        app.buttons["Añadir álbum"].firstMatch.tap()
        type(title, into: app.textFields["Título"])
        type(artist, into: app.textFields["Artista"])
        type(tracks.joined(separator: "\n"), into: app.textViews.firstMatch)
        app.navigationBars["Nuevo álbum"].buttons["Guardar"].tap()
    }

    private func rateTrack(_ position: Int, score: String, comment: String? = nil) {
        let track = app.buttons["track-\(position)"]
        XCTAssertTrue(track.waitForExistence(timeout: 10))
        track.tap()
        let scoreField = app.textFields["Nota"]
        XCTAssertTrue(scoreField.waitForExistence(timeout: 5))
        scoreField.typeText(score)
        if let comment { type(comment, into: app.textFields["¿Qué te ha parecido?"]) }
        app.buttons["Guardar"].tap()
        XCTAssertTrue(scoreField.waitForNonExistence(timeout: 10), "la hoja se cierra al confirmar el guardado")
    }

    private func signOut() {
        app.buttons["Perfil"].tap()
        app.buttons["Cerrar sesión"].tap()
        XCTAssertTrue(app.buttons["Create an account"].waitForExistence(timeout: 10))
    }

    private func type(_ text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "no aparece \(element)")
        element.tap()
        element.typeText(text)
    }

    /// En los campos de contraseña nueva, iOS ofrece «Use Strong Password?» y se queda con el
    /// teclado: el texto no llegaría al campo. El test cierra esa sugerencia y escribe la suya.
    private func typeSecure(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "no aparece \(field)")
        field.tap()
        if app.buttons["GenerateStrongPasswordButton"].waitForExistence(timeout: 2) {
            app.buttons["xmark"].tap()
            field.tap()
        }
        field.typeText(text)
        XCTAssertEqual((field.value as? String)?.count, text.count, "la contraseña no llegó completa a \(field)")
    }

    private func waitForLabel(of element: XCUIElement, containing text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10) == .completed
    }
}
