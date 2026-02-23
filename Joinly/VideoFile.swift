import AVFoundation
import Foundation
import UniformTypeIdentifiers

enum VideoFileError: LocalizedError {
    case notRegularFile(String)
    case unsupportedType(String)
    case missingVideoTrack(String)
    case invalidDuration(String)

    private var prefersEnglish: Bool {
        Locale.preferredLanguages.first?.hasPrefix("en") == true
    }

    var errorDescription: String? {
        switch self {
        case .notRegularFile(let file):
            return prefersEnglish ? "Not a regular file: \(file)" : "不是普通文件：\(file)"
        case .unsupportedType(let file):
            return prefersEnglish ? "Unsupported media type: \(file)" : "不支持的媒体类型：\(file)"
        case .missingVideoTrack(let file):
            return prefersEnglish ? "No video track found: \(file)" : "未找到视频轨道：\(file)"
        case .invalidDuration(let file):
            return prefersEnglish ? "Invalid media duration: \(file)" : "媒体时长无效：\(file)"
        }
    }
}

struct VideoFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let duration: Double
    let modifiedAt: Date?
    let fileSize: Int64? // 添加文件大小信息

    var fileName: String {
        url.lastPathComponent
    }

    var durationText: String {
        guard duration.isFinite else { return "--:--" }
        let total = Int(duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var modifiedText: String {
        guard let modifiedAt else { return "--" }
        return Self.modifiedFormatter.string(from: modifiedAt)
    }
    
    var fileSizeText: String {
        guard let fileSize = fileSize else { return "--" }
        return Self.formatFileSize(fileSize)
    }

    private static let modifiedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    private static func formatFileSize(_ bytes: Int64) -> String {
        let sizes = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var index = 0
        
        while size >= 1024 && index < sizes.count - 1 {
            size /= 1024
            index += 1
        }
        
        return String(format: "%.1f %@", size, sizes[index])
    }

    private static let fallbackVideoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mkv", "webm", "mpeg", "mpg"
    ]

    private static func isSupportedVideoType(_ resourceValues: URLResourceValues, url: URL) -> Bool {
        if let contentType = resourceValues.contentType {
            return contentType.conforms(to: .movie) || contentType.conforms(to: .video)
        }
        return fallbackVideoExtensions.contains(url.pathExtension.lowercased())
    }

    static func make(from url: URL) async throws -> VideoFile {
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .contentTypeKey
        ]

        let resourceValues = try url.resourceValues(forKeys: resourceKeys)
        guard resourceValues.isRegularFile != false else {
            throw VideoFileError.notRegularFile(url.lastPathComponent)
        }
        guard isSupportedVideoType(resourceValues, url: url) else {
            throw VideoFileError.unsupportedType(url.lastPathComponent)
        }

        let asset = AVURLAsset(url: url)
        let sourceVideoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !sourceVideoTracks.isEmpty else {
            throw VideoFileError.missingVideoTrack(url.lastPathComponent)
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw VideoFileError.invalidDuration(url.lastPathComponent)
        }

        return VideoFile(
            url: url,
            duration: durationSeconds,
            modifiedAt: resourceValues.contentModificationDate,
            fileSize: resourceValues.fileSize.map(Int64.init)
        )
    }
}
