import Foundation

extension FileManager {
    static var wrecApplicationSupportDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let wrecDir = appSupport.appendingPathComponent("wrec", isDirectory: true)

        if !FileManager.default.fileExists(atPath: wrecDir.path) {
            try? FileManager.default.createDirectory(at: wrecDir, withIntermediateDirectories: true)
        }

        return wrecDir
    }

    static var meetingsDirectory: URL {
        let meetingsDir = wrecApplicationSupportDirectory.appendingPathComponent("meetings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: meetingsDir.path) {
            try? FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)
        }

        return meetingsDir
    }

    static func createMeetingDirectory(title: String, date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = formatter.string(from: date)

        let sanitizedTitle = title
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:"))
            .joined()

        let meetingDir = meetingsDirectory.appendingPathComponent("\(dateString)_\(sanitizedTitle)", isDirectory: true)

        if !FileManager.default.fileExists(atPath: meetingDir.path) {
            try? FileManager.default.createDirectory(at: meetingDir, withIntermediateDirectories: true)
        }

        return meetingDir
    }

    static func deleteMeetingDirectory(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static var totalStorageUsed: Int64 {
        guard let enumerator = FileManager.default.enumerator(at: meetingsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else { continue }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    static func formattedStorageUsed() -> String {
        let bytes = totalStorageUsed
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
