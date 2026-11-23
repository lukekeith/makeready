//
//  VideoStreamTransportTests.swift
//  MakeReadyCaptureTests
//
//  The multipart body the Stream upload streams from disk (video-recorder D12).
//

import XCTest
@testable import MakeReady

final class VideoStreamTransportTests: XCTestCase {

    func testTheBodyHoldsTheFileBytesBetweenTheBoundaries() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stream-body-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        // Longer than one 1 MB chunk, so the copy loop runs more than once.
        let bytes = Data((0..<1_500_000).map { UInt8($0 % 251) })
        let file = dir.appendingPathComponent("video.mp4")
        try bytes.write(to: file)
        let body = dir.appendingPathComponent("body")

        try URLSessionVideoStreamTransport.writeMultipartBody(file: file, boundary: "B", to: body)

        let written = try Data(contentsOf: body)
        let head = Data("--B\r\nContent-Disposition: form-data; name=\"file\"; filename=\"video.mp4\"\r\nContent-Type: video/mp4\r\n\r\n".utf8)
        let tail = Data("\r\n--B--\r\n".utf8)
        XCTAssertEqual(written.prefix(head.count), head)
        XCTAssertEqual(written.suffix(tail.count), tail)
        XCTAssertEqual(written.dropFirst(head.count).dropLast(tail.count), bytes)
    }
}
