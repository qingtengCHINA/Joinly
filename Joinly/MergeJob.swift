import Foundation

enum MergeJobStatus: String, Hashable {
    case pending
    case running
    case completed
    case failed

    var title: String {
        switch self {
        case .pending:
            return "待处理"
        case .running:
            return "合并中"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        }
    }
}

struct MergeJob: Identifiable, Hashable {
    let id: UUID
    var title: String
    var files: [VideoFile]
    var outputURL: URL
    var createdAt: Date
    var progress: Double
    var status: MergeJobStatus
    var detail: String

    init(
        id: UUID = UUID(),
        title: String,
        files: [VideoFile],
        outputURL: URL,
        createdAt: Date = .now,
        progress: Double = 0,
        status: MergeJobStatus = .pending,
        detail: String = "等待开始"
    ) {
        self.id = id
        self.title = title
        self.files = files
        self.outputURL = outputURL
        self.createdAt = createdAt
        self.progress = progress
        self.status = status
        self.detail = detail
    }
    
    // 添加便利构造器用于复制工作
    init(copying original: MergeJob, withNewID: Bool = false) {
        self.id = withNewID ? UUID() : original.id
        self.title = original.title
        self.files = original.files
        self.outputURL = original.outputURL
        self.createdAt = original.createdAt
        self.progress = original.progress
        self.status = original.status
        self.detail = original.detail
    }
    
    // 添加辅助方法判断状态是否是最终状态
    var isFinalStatus: Bool {
        status == .completed || status == .failed
    }
}
