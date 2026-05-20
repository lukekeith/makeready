//
//  String+ImageVariants.swift
//  MakeReady
//
//  Extension for deriving image variant URLs from base image URLs.
//  The server generates three variants on upload:
//  - Original (max 1200px): filename.jpeg
//  - Medium (max 400px): filename-md.jpeg
//  - Thumbnail (max 150px): filename-thumb.jpeg
//

import Foundation

extension String {
    /// Returns URL for medium-sized image variant (400px max width)
    /// Use for card grids and medium-sized displays
    var mediumImageUrl: String {
        guard let dotIndex = self.lastIndex(of: ".") else { return self }
        let base = String(self[..<dotIndex])
        let ext = String(self[dotIndex...])
        return "\(base)-md\(ext)"
    }

    /// Returns URL for thumbnail image variant (150px max width)
    /// Use for small thumbnails and list rows
    var thumbImageUrl: String {
        guard let dotIndex = self.lastIndex(of: ".") else { return self }
        let base = String(self[..<dotIndex])
        let ext = String(self[dotIndex...])
        return "\(base)-thumb\(ext)"
    }
}
