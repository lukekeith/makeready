//
//  VideoNamingModelTests.swift
//  MakeReadyCaptureTests
//
//  video-naming D3, D4, D5, D15, D16, D17, D18: `VideoNamingModel` over a scripted transcript and a
//  `SuggestSpy` whose asks the test answers or fails.
//

import XCTest
@testable import MakeReady

/// Records every ask and holds it until the test answers or fails it.
@MainActor
private final class SuggestSpy {
    private(set) var asked: [String] = []
    private var pending: [CheckedContinuation<[VideoDetailSuggestion], Error>] = []

    func suggest(_ transcript: String) async throws -> [VideoDetailSuggestion] {
        asked.append(transcript)
        return try await withCheckedThrowingContinuation { pending.append($0) }
    }

    func answer(_ suggestions: [VideoDetailSuggestion]) { pending.removeFirst().resume(returning: suggestions) }
    func fail(_ error: Error) { pending.removeFirst().resume(throwing: error) }
    func failAll() { while !pending.isEmpty { fail(CancellationError()) } }
}

@MainActor
final class VideoNamingModelTests: XCTestCase {

    private var spy: SuggestSpy!
    private var saves: [(title: String, description: String)] = []
    private var saveSucceeds = true
    private var models: [VideoNamingModel] = []

    override func setUp() {
        super.setUp()
        spy = SuggestSpy()
        saves = []
        saveSucceeds = true
        models = []
    }

    override func tearDown() {
        spy.failAll()
        super.tearDown()
    }

    private let three = [
        VideoDetailSuggestion(title: "One", description: "First"),
        VideoDetailSuggestion(title: "Two", description: "Second"),
        VideoDetailSuggestion(title: "Three", description: "Third"),
    ]

    private func make(transcript: String?) -> VideoNamingModel {
        let model = VideoNamingModel(
            titlePlaceholder: "Video 4",
            transcript: { transcript },
            suggest: { [spy] text in try await spy!.suggest(text) },
            save: { [unowned self] title, description in
                saves.append((title, description))
                return saveSucceeds
            },
            back: {})
        models.append(model)
        return model
    }

    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testSuggestionsLoadAndAPickFillsBoth() async {
        let m = make(transcript: "hello"); m.open(); await settle()
        XCTAssertEqual(m.block, .generating)
        spy.answer(three); await settle()
        XCTAssertEqual(m.block, .list); XCTAssertEqual(m.suggestions, three); XCTAssertEqual(m.title, "")
        m.setTitle("mine"); m.pick(1); m.pick(7)
        XCTAssertEqual(m.title, three[1].title); XCTAssertEqual(m.description, three[1].description)
        m.setTitle("after"); m.regenerate(); await settle()
        XCTAssertEqual(m.block, .regenerating); XCTAssertEqual(m.suggestions, three)
        spy.answer(Array(three.reversed())); await settle()
        XCTAssertEqual(m.title, "after"); XCTAssertEqual(m.suggestions, Array(three.reversed()))
    }

    func testNoTranscriptIsEmpty() async {
        for text in [nil, "  \n"] as [String?] {
            let m = make(transcript: text); m.open(); await settle()
            XCTAssertEqual(m.block, .empty); XCTAssertEqual(m.promptCopy, "No speech to suggest from")
            m.regenerate(); await settle()
            XCTAssertTrue(spy.asked.isEmpty)
        }
    }

    func testFailuresFollowD16() async {
        let m = make(transcript: "hello"); m.open(); await settle()
        spy.fail(URLError(.timedOut)); await settle()
        XCTAssertEqual(m.block, .prompt); XCTAssertEqual(m.promptCopy, "Couldn't get suggestions")
        m.regenerate(); await settle()
        XCTAssertEqual(m.block, .generating)
        spy.answer(three); await settle(); m.regenerate(); await settle()
        spy.fail(URLError(.timedOut)); await settle()
        XCTAssertEqual(m.block, .list); XCTAssertEqual(m.suggestions, three)
    }

    func testAnAnswerAfterLeavingIsDropped() async {
        let m = make(transcript: "hello"); m.open(); await settle()
        m.leave()
        spy.answer(three); await settle()
        XCTAssertTrue(m.suggestions.isEmpty)
    }

    func testCapsAndOneSave() async {
        let m = make(transcript: String(repeating: "x", count: 20_500)); m.open(); await settle()
        XCTAssertEqual(spy.asked.first?.utf16.count, 20_000)
        m.setTitle(String(repeating: "t", count: 90)); m.setDescription(String(repeating: "d", count: 310))
        XCTAssertEqual(m.title.count, 80); XCTAssertEqual(m.description.count, 300)
        saveSucceeds = false; m.saveTapped(); saveSucceeds = true; m.saveTapped(); m.saveTapped()
        XCTAssertEqual(saves.count, 2)
    }
}
