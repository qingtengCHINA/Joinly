import AVFoundation
import Foundation

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

    static func make(from url: URL) async -> VideoFile {
        let asset = AVURLAsset(url: url)
        let durationSeconds: Double
        var fileSize: Int64?

        // 获取文件修改时间和大小
        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modifiedAt = resourceValues.contentModificationDate
            
            if let size = resourceValues.fileSize {
                fileSize = Int64(size)
            }
            
            let duration = try await asset.load(.duration)
            durationSeconds = CMTimeGetSeconds(duration)
            
            return VideoFile(url: url, duration: durationSeconds, modifiedAt: modifiedAt, fileSize: fileSize)
        } catch {
            // 如果获取资源值失败，则回退到基本实现
            let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            
            do {
                let duration = try await asset.load(.duration)
                durationSeconds = CMTimeGetSeconds(duration)
            } catch {
                durationSeconds = 0
            }
            
            return VideoFile(url: url, duration: durationSeconds, modifiedAt: modifiedAt, fileSize: fileSize)
        }
    }
}
