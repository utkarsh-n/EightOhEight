import XCTest

final class MachineUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skin", "original"]
        app.launch()
        XCTAssertTrue(control("mode-selector").waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testCompleteLandscapePanelIsReachable() {
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        let identifiers = [
            "mode-selector", "instrument-selector", "tempo", "tempo-fine",
            "auto-fill", "master-volume", "basic-variation", "fill-variation",
            "prescale", "clear-pattern", "start-stop", "tap"
        ] + (0..<12).map { "instrument-\($0)" }
          + (1...16).map { "step-\($0)" }

        for identifier in identifiers {
            let element = control(identifier)
            XCTAssertTrue(element.exists, "Missing control: \(identifier)")
            XCTAssertTrue(element.isHittable, "Control requires scrolling or zoom: \(identifier)")
        }
    }

    func testStepEditsRemainIndependentBetweenVariations() {
        control("instrument-1").tap()
        let step = control("step-2")
        let variation = control("basic-variation")
        assertValue("A", on: variation)
        assertValue("Off", on: step)
        step.tap()
        assertValue("On", on: step)

        variation.tap() // A -> AB -> B
        variation.tap()
        assertValue("B", on: variation)
        assertValue("Off", on: step)
        step.tap()
        assertValue("On", on: step)

        variation.tap()
        assertValue("A", on: variation)
        assertValue("On", on: step)
        step.tap()
        assertValue("Off", on: step)

        variation.tap()
        variation.tap()
        assertValue("B", on: variation)
        assertValue("On", on: step)
    }

    func testTransportStartsAndStopsTheRhythm() {
        let transport = control("start-stop")
        assertValue("Stopped", on: transport)
        transport.tap()
        assertValue("Playing", on: transport)
        transport.tap()
        assertValue("Stopped", on: transport)
    }

    func testVerticalTempoKnobDragChangesTempo() throws {
        let knob = control("tempo")
        let before = try tempoValue(knob)
        let start = knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: -40))
        start.press(forDuration: 0.2, thenDragTo: end)
        XCTAssertGreaterThan(try tempoValue(knob), before)
    }

    func testStudioSkinOffersReachableTouchTargetsAndRhythmEditing() {
        launchSkin("studio")
        assertTouchTargets(additional: ["mode-selector", "pattern-selector", "basic-variation",
                                        "part-selector", "timing-selector", "clear-pattern", "tempo-fine"])
        control("instrument-3").tap()
        control("timing-selector").tap()
        XCTAssertTrue(control("alternate-3").waitForExistence(timeout: 3))
        XCTAssertTrue(control("alternate-3").isHittable)
        control("alternate-3").tap()
        let conga = app.buttons["Low Conga"]
        XCTAssertTrue(conga.waitForExistence(timeout: 3))
        conga.tap()
        XCTAssertTrue(app.staticTexts["Low Conga"].waitForExistence(timeout: 3))
        control("instrument-1").tap()
        assertValue("Selected", on: control("instrument-1"))
        assertValue("Off", on: control("step-2"))
        control("step-2").tap()
        assertValue("On", on: control("step-2"))
        verifyTransport()
        capturePanel("Studio 808")
    }

    func testGlassSkinOffersNativeParameterAndRhythmControls() throws {
        launchSkin("glass")
        assertTouchTargets(additional: ["mode-selector", "pattern-selector", "part-length",
                                        "prescale", "fill", "clear-pattern", "audition"])
        control("instrument-1").tap()
        assertValue("Selected", on: control("instrument-1"))
        assertValue("Off", on: control("step-2"))
        control("step-2").tap()
        assertValue("On", on: control("step-2"))

        let level = app.sliders.matching(identifier: "knob-1-level").firstMatch
        XCTAssertTrue(level.isHittable, "The selected voice's native level slider is unreachable")
        let before = try XCTUnwrap(level.value as? String)
        level.adjust(toNormalizedSliderPosition: 0.25)
        XCTAssertNotEqual(try XCTUnwrap(level.value as? String), before)
        verifyTransport()
        capturePanel("Digital 808")
        selectSkinFromOptions("Studio 808", panelIdentifier: "studio-panel")
        capturePanel("Studio 808")
    }

    func testSwitchingSkinsPreservesEditedRhythmAndActivePlayback() {
        launchSkin("studio")
        control("instrument-1").tap()
        control("step-2").tap()
        assertValue("On", on: control("step-2"))
        control("start-stop").tap()
        assertValue("Playing", on: control("start-stop"))

        for skin in ["glass", "original", "studio"] {
            // UIKit renders Menu rows with their visible titles rather than SwiftUI IDs.
            let title = ["glass": "Digital 808", "original": "Original 808", "studio": "Studio 808"][skin]!
            let panelIdentifier = skin == "original" ? "mode-selector" : "\(skin)-panel"
            selectSkinFromOptions(title, panelIdentifier: panelIdentifier)
            assertValue("On", on: control("step-2"))
            assertValue("Playing", on: control("start-stop"))
        }
        control("start-stop").tap()
        assertValue("Stopped", on: control("start-stop"))
    }

    private func launchSkin(_ skin: String) {
        app.terminate()
        app.launchArguments = ["--uitesting", "--skin", skin]
        app.launch()
        XCTAssertTrue(control("\(skin)-panel").waitForExistence(timeout: 10))
    }

    private func selectSkinFromOptions(_ title: String, panelIdentifier: String) {
        control("machine-options").tap()
        let skins = app.buttons["Skins"]
        XCTAssertTrue(skins.waitForExistence(timeout: 3))
        skins.tap()
        let option = app.buttons[title]
        XCTAssertTrue(option.waitForExistence(timeout: 3))
        option.tap()
        XCTAssertTrue(control(panelIdentifier).waitForExistence(timeout: 5))
    }

    private func assertTouchTargets(additional: [String] = [],
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(app.frame.width, app.frame.height, file: file, line: line)
        let identifiers = (0..<12).map { "instrument-\($0)" }
            + (1...16).map { "step-\($0)" }
            + ["start-stop", "tap", "machine-options"] + additional
        for identifier in identifiers {
            assertTouchTarget(identifier, file: file, line: line)
        }
    }

    private func assertTouchTarget(_ identifier: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let element = control(identifier)
        XCTAssertTrue(element.exists, "Missing \(identifier)", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Unreachable \(identifier)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.width, 43.5,
                                   "Narrow touch target: \(identifier)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, 43.5,
                                   "Short touch target: \(identifier)", file: file, line: line)
    }

    private func verifyTransport() {
        let transport = control("start-stop")
        assertValue("Stopped", on: transport)
        transport.tap()
        assertValue("Playing", on: transport)
        transport.tap()
        assertValue("Stopped", on: transport)
    }

    private func capturePanel(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func control(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func assertValue(_ value: String, on element: XCUIElement,
                             file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value), object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "Expected \(value), found \(String(describing: element.value))", file: file, line: line)
    }

    private func tempoValue(_ element: XCUIElement) throws -> Int {
        let text = try XCTUnwrap(element.value as? String)
        return try XCTUnwrap(Int(text.split(separator: " ").first.map(String.init) ?? ""))
    }
}
