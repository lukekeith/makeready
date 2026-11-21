//
//  MemoStorage.swift
//  MakeReady
//
//  Where a signed-in user's unsent memos live (D37): `<root>/memos/<environment>/<userId>/`,
//  excluded from iCloud backup. One folder per user and environment, so a flush or a salvage
//  can only ever see its own owner's files.
//

import Foundation

enum MemoStorage {

    /// Creates (if needed) and returns the queue folder. `root` defaults to Application Support;
    /// tests pass a temp folder so they never write the real one.
    static func folder(environment: String, userId: String, root: URL? = nil) throws -> URL {
        let base = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
        var folder = base.appendingPathComponent("memos", isDirectory: true)
            .appendingPathComponent(environment, isDirectory: true)
            .appendingPathComponent(userId, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        return folder
    }

    /// Where this folder's draft manifests and `.caf` files sit. The queue reads only `*.json`
    /// directly inside its folder, so drafts live one level down.
    static func draftsFolder(in folder: URL) -> URL {
        folder.appendingPathComponent("drafts", isDirectory: true)
    }
}
