import AVFoundation
import Foundation

enum MergeError: LocalizedError {
    case emptySelection
    case missingVideoTrack(String)
    case invalidTrackDuration(String)
    case unsupportedOutput
    case exportCreationFailed
    case exportFailed(String)
    case insufficientDiskSpace

    private var prefersEnglish: Bool {
        Locale.preferredLanguages.first?.hasPrefix("en") == true
    }

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return prefersEnglish ? "Please add at least one video file." : "请先添加至少一个视频文件。"
        case .missingVideoTrack(let file):
            return prefersEnglish ? "No video track found: \(file)" : "文件不含视频轨道：\(file)"
        case .invalidTrackDuration(let file):
            return prefersEnglish ? "Invalid media duration: \(file)" : "媒体时长无效：\(file)"
        case .unsupportedOutput:
            return prefersEnglish ? "Only .mov and .mp4 are supported for output." : "输出格式仅支持 .mov 或 .mp4"
        case .exportCreationFailed:
            return prefersEnglish ? "Failed to create export session." : "创建导出会话失败。"
        case .exportFailed(let message):
            return prefersEnglish ? "Merge failed: \(message)" : "合并失败：\(message)"
        case .insufficientDiskSpace:
            return prefersEnglish ? "Insufficient disk space for merging." : "磁盘空间不足，无法完成合并。"
        }
    }
}

final class VideoMerger {
    // 检查是否有足够的磁盘空间
    private func hasSufficientDiskSpace(for files: [VideoFile], outputURL: URL) -> Bool {
        // 获取所有输入文件大小
        var totalInputSize: UInt64 = 0
        
        for file in files {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: file.url.path)
                if let fileSize = attrs[.size] as? NSNumber {
                    totalInputSize += fileSize.uint64Value
                }
            } catch {
                // 如果无法获取文件大小，则跳过检查
                continue
            }
        }
        
        // 预估输出文件可能需要的空间（我们假设最多是原始大小的1.5倍）
        let estimatedOutputSize = Int64(Double(totalInputSize) * 1.5)
        
        // 检查输出目录的可用空间
        do {
            let outputDir = outputURL.deletingLastPathComponent()
            let values = try outputDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
                return availableCapacity >= estimatedOutputSize
            }
        } catch {
            // 如果无法检查磁盘空间，则假设足够
            return true
        }
        
        return true
    }
    
    func merge(
        files: [VideoFile],
        outputURL: URL
    ) async throws {
        guard !files.isEmpty else { throw MergeError.emptySelection }
        
        // 检查磁盘空间
        guard hasSufficientDiskSpace(for: files, outputURL: outputURL) else {
            throw MergeError.insufficientDiskSpace
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MergeError.exportCreationFailed
        }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero

        for (index, file) in files.enumerated() {
            let asset = AVURLAsset(url: file.url)
            let sourceVideoTracks = try await asset.loadTracks(withMediaType: .video)

            guard let sourceVideoTrack = sourceVideoTracks.first else {
                throw MergeError.missingVideoTrack(file.fileName)
            }

            if index == 0 {
                videoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
            }

            let assetDuration = try await asset.load(.duration)
            let videoTrackRange = try await sourceVideoTrack.load(.timeRange)
            let segmentDuration = minimumPositiveDuration(assetDuration, videoTrackRange.duration)
            guard isPositiveDuration(segmentDuration) else {
                throw MergeError.invalidTrackDuration(file.fileName)
            }

            let videoRange = CMTimeRange(start: .zero, duration: segmentDuration)
            try videoTrack.insertTimeRange(videoRange, of: sourceVideoTrack, at: cursor)

            let sourceAudioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let sourceAudioTrack = sourceAudioTracks.first, let audioTrack {
                let audioTrackRange = try await sourceAudioTrack.load(.timeRange)
                let audioDuration = minimumPositiveDuration(segmentDuration, audioTrackRange.duration)
                if isPositiveDuration(audioDuration) {
                    let audioRange = CMTimeRange(start: .zero, duration: audioDuration)
                    try audioTrack.insertTimeRange(audioRange, of: sourceAudioTrack, at: cursor)
                }
            }

            cursor = cursor + segmentDuration
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let fileType = outputFileType(for: outputURL) else {
            throw MergeError.unsupportedOutput
        }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw MergeError.exportCreationFailed
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = fileType
        exporter.shouldOptimizeForNetworkUse = true

        do {
            try await exporter.export(to: outputURL, as: fileType)
        } catch {
            let message = exporter.error?.localizedDescription ?? error.localizedDescription
            throw MergeError.exportFailed(message)
        }
    }

    private func outputFileType(for url: URL) -> AVFileType? {
        switch url.pathExtension.lowercased() {
        case "mov":
            return .mov
        case "mp4":
            return .mp4
        default:
            return nil
        }
    }

    private func isPositiveDuration(_ duration: CMTime) -> Bool {
        duration.isValid && duration.isNumeric && CMTimeCompare(duration, .zero) > 0
    }

    private func minimumPositiveDuration(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
        let lhsPositive = isPositiveDuration(lhs)
        let rhsPositive = isPositiveDuration(rhs)

        switch (lhsPositive, rhsPositive) {
        case (true, true):
            return CMTimeCompare(lhs, rhs) <= 0 ? lhs : rhs
        case (true, false):
            return lhs
        case (false, true):
            return rhs
        case (false, false):
            return .zero
        }
    }
}
