import Foundation
import ImageIO

/// media-page D3: the date a picked photo was taken, read from its bytes while they still exist
/// (the cover is re-encoded before upload, which strips EXIF). `DateTimeOriginal` is a wall-clock
/// time; its zone is `OffsetTimeOriginal` when the file carries one, else the device's. The result
/// is ISO 8601 with an offset ("2025-06-14T09:30:00-05:00"), or nil when the file has no date.
enum CaptureDate {
    static func read(from data: Data, deviceTimeZone: TimeZone = .current) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let zone = (exif[kCGImagePropertyExifOffsetTimeOriginal] as? String).flatMap(timeZone(offset:)) ?? deviceTimeZone
        return format(exifDateTime: original, in: zone)
    }

    /// "yyyy:MM:dd HH:mm:ss" read as a wall-clock time in `zone`.
    static func format(exifDateTime raw: String, in zone: TimeZone) -> String? {
        let parts = raw.split(whereSeparator: { $0 == ":" || $0 == " " }).compactMap { Int($0) }
        guard parts.count == 6, parts[0] >= 1900, (1...12).contains(parts[1]), (1...31).contains(parts[2]),
              (0...23).contains(parts[3]), (0...59).contains(parts[4]), (0...60).contains(parts[5]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                        hour: parts[3], minute: parts[4], second: parts[5])
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        return "\(parts[0])-\(two(parts[1]))-\(two(parts[2]))T\(two(parts[3])):\(two(parts[4])):\(two(parts[5]))"
            + "\(sign)\(two(magnitude / 3600)):\(two((magnitude % 3600) / 60))"
    }

    /// "+05:30" / "-07:00" → that fixed zone; anything else nil.
    static func timeZone(offset: String) -> TimeZone? {
        guard let first = offset.first, first == "+" || first == "-" else { return nil }
        let fields = offset.dropFirst().split(separator: ":").compactMap { Int($0) }
        guard fields.count == 2, (0...14).contains(fields[0]), (0..<60).contains(fields[1]) else { return nil }
        let seconds = fields[0] * 3600 + fields[1] * 60
        return TimeZone(secondsFromGMT: first == "-" ? -seconds : seconds)
    }
}
