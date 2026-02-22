import SwiftUI
import UniformTypeIdentifiers

private enum FileSortMode: String, CaseIterable, Identifiable {
    case manual
    case fileName
    case fileTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "手动"
        case .fileName:
            return "文件名"
        case .fileTime:
            return "文件时间"
        }
    }
}

private actor MergeIDQueue {
    private var ids: [UUID]

    init(ids: [UUID]) {
        self.ids = ids
    }

    func next() -> UUID? {
        guard !ids.isEmpty else { return nil }
        return ids.removeFirst()
    }
    
    func cancel(_ id: UUID) {
        ids.removeAll { $0 == id }
    }
}

struct ContentView: View {
    @AppStorage("defaultOutputFolderPath") private var defaultOutputFolderPath = ""
    @AppStorage("maxParallelJobs") private var maxParallelJobs = 2
    @AppStorage("language") private var language = "zh"
    @State private var files: [VideoFile] = []
    @State private var selectedFileID: VideoFile.ID?

    @State private var jobs: [MergeJob] = []
    @State private var selectedJobID: MergeJob.ID?

    @State private var fileSortMode: FileSortMode = .manual
    @State private var sortAscending = true

    @State private var draftGroupName = "组 1"
    @State private var isQueueRunning = false
    @State private var statusMessage = "准备就绪"
    @State private var globalProgress = 0.0
    @State private var errorMessage: String?
    
    @State private var isDraggingOver = false
    
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 16) {
                header

                HStack(spacing: 16) {
                    groupEditor
                    queuePanel
                }
                .frame(maxHeight: .infinity)

                footer
            }
            .padding(22)
        }
        .alert("合并失败", isPresented: .constant(errorMessage != nil)) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: fileSortMode) { _ in
            applySortIfNeeded()
        }
        .onChange(of: sortAscending) { _ in
            applySortIfNeeded()
        }
        .onDrop(of: [.fileURL], delegate: FileDropDelegate(onDrop: handleDroppedFiles))
        .environment(\.locale, Locale(identifier: language))
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.89, green: 0.94, blue: 0.99),
                    Color(red: 0.84, green: 0.91, blue: 0.98),
                    Color(red: 0.93, green: 0.98, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.55, green: 0.79, blue: 0.95).opacity(0.22))
                .frame(width: 460, height: 460)
                .offset(x: -320, y: -240)
                .blur(radius: 4)

            Circle()
                .fill(Color(red: 0.32, green: 0.72, blue: 0.80).opacity(0.20))
                .frame(width: 520, height: 520)
                .offset(x: 340, y: 220)
                .blur(radius: 6)
                
            if isDraggingOver {
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .overlay(
                        Text("释放文件以添加到当前组")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding()
                    )
                    .cornerRadius(20)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Joinly")
                    .font(.custom("AvenirNext-Heavy", size: 36))

                Text(language == "en" ? "Lossless Batch Splicing Engine" : "无损批量拼接引擎")
                    .font(.custom("AvenirNext-Medium", size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(language == "en" ? "Add Videos" : "添加视频", action: pickVideos)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("o", modifiers: [.command])

                Button(language == "en" ? "Clear Current Group" : "清空当前组") {
                    files.removeAll()
                    selectedFileID = nil
                    statusMessage = language == "en" ? "Current group cleared" : "当前组已清空"
                }
                .buttonStyle(.bordered)
                .disabled(isQueueRunning || files.isEmpty)

                Button {
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
            }
        }
        .glassPanel(radius: 22)
    }

    private var groupEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language == "en" ? "File Group Editor" : "文件组编辑")
                    .font(.custom("AvenirNext-DemiBold", size: 18))

                Spacer()

                Text("\(files.count) \(language == "en" ? "files" : "个文件")")
                    .font(.custom("Menlo-Regular", size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField(language == "en" ? "Group Name" : "文件组名称", text: $draftGroupName)
                    .textFieldStyle(.roundedBorder)

                Picker(language == "en" ? "Sort" : "排序", selection: $fileSortMode) {
                    ForEach(FileSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 108)

                Button(sortAscending ? (language == "en" ? "Ascending" : "升序") : (language == "en" ? "Descending" : "降序")) {
                    sortAscending.toggle()
                }
                .buttonStyle(.bordered)
                .disabled(fileSortMode == .manual)
            }

            List(selection: $selectedFileID) {
                ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                    HStack(spacing: 10) {
                        Text(String(format: "%02d", index + 1))
                            .font(.custom("Menlo-Regular", size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName)
                                .lineLimit(1)
                                .font(.custom("AvenirNext-Medium", size: 13))

                            Text(language == "en" ? "Modified: \(file.modifiedText)" : "修改时间：\(file.modifiedText)")
                                .lineLimit(1)
                                .font(.custom("Menlo-Regular", size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(file.durationText)
                            .font(.custom("Menlo-Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(file.id)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.white.opacity(0.26))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.30), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Button(language == "en" ? "Move Up" : "上移", action: moveUp)
                    .disabled(!canMoveUp)

                Button(language == "en" ? "Move Down" : "下移", action: moveDown)
                    .disabled(!canMoveDown)

                Spacer()

                Button(language == "en" ? "Add to Batch" : "加入批处理", action: enqueueCurrentGroup)
                    .buttonStyle(.borderedProminent)
                    .disabled(files.isEmpty || isQueueRunning)
            }
            .buttonStyle(.bordered)
        }
        .glassPanel(radius: 22)
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language == "en" ? "Concurrent Tasks" : "并发任务")
                    .font(.custom("AvenirNext-DemiBold", size: 18))

                Spacer()

                Text(language == "en" ? "Concurrency \(maxParallelJobs)" : "并发 \(maxParallelJobs)")
                    .font(.custom("Menlo-Regular", size: 12))
                    .foregroundStyle(.secondary)
            }

            List(selection: $selectedJobID) {
                ForEach(jobs) { job in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(job.title)
                                .lineLimit(1)
                                .font(.custom("AvenirNext-DemiBold", size: 13))

                            Spacer()

                            Text(job.status.title)
                                .font(.custom("Menlo-Regular", size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(statusColor(job.status).opacity(0.18), in: Capsule())
                        }

                        Text(job.outputURL.lastPathComponent)
                            .lineLimit(1)
                            .font(.custom("Menlo-Regular", size: 10))
                            .foregroundStyle(.secondary)

                        LiquidProgressBar(progress: job.progress, isActive: job.status == .running)
                            .frame(height: 14)

                        Text(job.detail)
                            .font(.custom("AvenirNext-Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .tag(job.id)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.white.opacity(0.26))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.30), lineWidth: 1)
            )

            HStack(spacing: 8) {
                Button(language == "en" ? "Start Concurrent Merge" : "开始并发合并", action: startBatchMerge)
                    .buttonStyle(.borderedProminent)
                    .disabled(isQueueRunning || jobs.isEmpty)

                Button(language == "en" ? "Remove Selected" : "移除选中") {
                    removeSelectedJob()
                }
                .buttonStyle(.bordered)
                .disabled(isQueueRunning || selectedJobID == nil)

                Button(language == "en" ? "Clean Completed" : "清理完成") {
                    jobs.removeAll { $0.status == .completed }
                    selectedJobID = nil
                    recalculateGlobalProgress()
                }
                .buttonStyle(.bordered)
                .disabled(isQueueRunning || !jobs.contains(where: { $0.status == .completed }))
            }
        }
        .frame(width: 360)
        .glassPanel(radius: 22)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusMessage)
                        .font(.custom("AvenirNext-Medium", size: 13))

                    Text(defaultOutputFolderPath.isEmpty ? 
                         (language == "en" ? "Default output directory: Not set (will be selected per group when adding to batch)" : 
                          "默认输出目录：未设置（加入批处理时会逐组选择）") : 
                         (language == "en" ? "Default output directory: \(defaultOutputFolderPath)" : 
                          "默认输出目录：\(defaultOutputFolderPath)"))
                        .lineLimit(1)
                        .font(.custom("Menlo-Regular", size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(language == "en" ? "Total Progress \(Int(globalProgress * 100))%" : "总进度 \(Int(globalProgress * 100))%")
                    .font(.custom("Menlo-Regular", size: 12))
                    .foregroundStyle(.secondary)
            }

            LiquidProgressBar(progress: globalProgress, isActive: isQueueRunning)
        }
        .glassPanel(radius: 22)
    }

    private var selectedFileIndex: Int? {
        guard let selectedFileID else { return nil }
        return files.firstIndex { $0.id == selectedFileID }
    }

    private var canMoveUp: Bool {
        guard fileSortMode == .manual, let index = selectedFileIndex else { return false }
        return index > 0 && !isQueueRunning
    }

    private var canMoveDown: Bool {
        guard fileSortMode == .manual, let index = selectedFileIndex else { return false }
        return index < files.count - 1 && !isQueueRunning
    }

    private func statusColor(_ status: MergeJobStatus) -> Color {
        switch status {
        case .pending:
            return .gray
        case .running:
            return Color(red: 0.10, green: 0.64, blue: 0.88)
        case .completed:
            return Color(red: 0.10, green: 0.65, blue: 0.48)
        case .failed:
            return Color(red: 0.88, green: 0.35, blue: 0.34)
        }
    }

    private func pickVideos() {
        let panel = NSOpenPanel()
        panel.title = language == "en" ? "Select videos to add to the current file group" : "选择要加入当前文件组的视频"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .video]

        if panel.runModal() == .OK {
            Task {
                statusMessage = language == "en" ? "Reading video information..." : "读取视频信息中..."
                let newItems = await withTaskGroup(of: Result<VideoFile, Error>.self) { group -> [VideoFile] in
                    for url in panel.urls {
                        group.addTask {
                            do {
                                let file = await VideoFile.make(from: url)
                                return .success(file)
                            } catch {
                                return .failure(error)
                            }
                        }
                    }

                    var results: [Result<VideoFile, Error>] = []
                    for await result in group {
                        results.append(result)
                    }
                    
                    let successfulFiles = results.compactMap { try? $0.get() }
                    let failedCount = results.count - successfulFiles.count
                    
                    if failedCount > 0 {
                        await MainActor.run {
                            statusMessage = language == "en" ? 
                                "Added \(successfulFiles.count) files, \(failedCount) files failed to read" : 
                                "已添加 \(successfulFiles.count) 个文件，\(failedCount) 个文件读取失败"
                        }
                    }
                    
                    return successfulFiles
                }

                let existing = Set(files.map(\.url))
                let uniqueNew = newItems.filter { !existing.contains($0.url) }
                files.append(contentsOf: uniqueNew)
                applySortIfNeeded()

                if draftGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draftGroupName = language == "en" ? "Group \(jobs.count + 1)" : "组 \(jobs.count + 1)"
                }

                if newItems.count == uniqueNew.count {
                    statusMessage = language == "en" ? "Added \(uniqueNew.count) files" : "已添加 \(uniqueNew.count) 个文件"
                }
            }
        }
    }

    private func handleDroppedFiles(_ urls: [URL]) {
        Task {
            statusMessage = language == "en" ? "Reading video information..." : "读取视频信息中..."
            let newItems = await withTaskGroup(of: Result<VideoFile, Error>.self) { group -> [VideoFile] in
                for url in urls where url.isFileURL {
                    group.addTask {
                        do {
                            let file = await VideoFile.make(from: url)
                            return .success(file)
                        } catch {
                            return .failure(error)
                        }
                    }
                }

                var results: [Result<VideoFile, Error>] = []
                for await result in group {
                    results.append(result)
                }
                
                let successfulFiles = results.compactMap { try? $0.get() }
                let failedCount = results.count - successfulFiles.count
                
                if failedCount > 0 {
                    await MainActor.run {
                        statusMessage = language == "en" ? 
                            "Added \(successfulFiles.count) files, \(failedCount) files failed to read" : 
                            "已添加 \(successfulFiles.count) 个文件，\(failedCount) 个文件读取失败"
                    }
                }
                
                return successfulFiles
            }

            let existing = Set(files.map(\.url))
            let uniqueNew = newItems.filter { !existing.contains($0.url) }
            files.append(contentsOf: uniqueNew)
            applySortIfNeeded()

            if draftGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draftGroupName = language == "en" ? "Group \(jobs.count + 1)" : "组 \(jobs.count + 1)"
            }

            if newItems.count == uniqueNew.count {
                statusMessage = language == "en" ? "Added \(uniqueNew.count) files" : "已添加 \(uniqueNew.count) 个文件"
            }
            
            isDraggingOver = false
        }
    }

    private func moveUp() {
        guard let index = selectedFileIndex, index > 0 else { return }
        files.swapAt(index, index - 1)
    }

    private func moveDown() {
        guard let index = selectedFileIndex, index < files.count - 1 else { return }
        files.swapAt(index, index + 1)
    }

    private func removeSelectedJob() {
        guard let selectedJobID else { return }
        jobs.removeAll { $0.id == selectedJobID }
        self.selectedJobID = nil
        recalculateGlobalProgress()
    }

    private func enqueueCurrentGroup() {
        guard !files.isEmpty else {
            statusMessage = language == "en" ? "Current group is empty, cannot add to batch processing" : "当前组为空，无法加入批处理"
            return
        }

        let trimmedName = draftGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupName = trimmedName.isEmpty ? 
            (language == "en" ? "Group \(jobs.count + 1)" : "组 \(jobs.count + 1)") : trimmedName
        let fileName = sanitizeFileName(groupName)

        guard let outputURL = resolveOutputURL(preferredBaseName: fileName) else {
            statusMessage = language == "en" ? "Cancelled adding to batch processing" : "已取消加入批处理"
            return
        }

        let job = MergeJob(title: groupName, files: files, outputURL: outputURL)
        jobs.append(job)

        statusMessage = language == "en" ? "Added task: \(groupName)" : "已加入任务：\(groupName)"
        files.removeAll()
        selectedFileID = nil
        draftGroupName = language == "en" ? "Group \(jobs.count + 1)" : "组 \(jobs.count + 1)"

        recalculateGlobalProgress()
    }

    private func applySortIfNeeded() {
        switch fileSortMode {
        case .manual:
            return
        case .fileName:
            files.sort { lhs, rhs in
                lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
            }
        case .fileTime:
            files.sort { lhs, rhs in
                let left = lhs.modifiedAt ?? .distantPast
                let right = rhs.modifiedAt ?? .distantPast
                return left < right
            }
        }

        if !sortAscending {
            files.reverse()
        }
    }

    private func startBatchMerge() {
        let pendingIDs = jobs.filter { $0.status == .pending || $0.status == .failed }.map(\.id)
        guard !pendingIDs.isEmpty else {
            statusMessage = language == "en" ? "No pending tasks" : "没有待处理任务"
            return
        }

        isQueueRunning = true
        statusMessage = language == "en" ? 
            "Starting concurrent merge, task count: \(pendingIDs.count)" : 
            "开始并发合并，任务数：\(pendingIDs.count)"

        let workers = min(max(1, maxParallelJobs), pendingIDs.count)
        let queue = MergeIDQueue(ids: pendingIDs)

        Task {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<workers {
                    group.addTask {
                        while let id = await queue.next() {
                            await runMergeJob(id: id)
                        }
                    }
                }
                
                for await _ in group {}
            }

            await MainActor.run {
                isQueueRunning = false
                recalculateGlobalProgress()

                let completed = jobs.filter { $0.status == .completed }.count
                let failed = jobs.filter { $0.status == .failed }.count
                statusMessage = language == "en" ? 
                    "Batch processing complete: \(completed) succeeded, \(failed) failed" : 
                    "批处理完成：\(completed) 成功，\(failed) 失败"
            }
        }
    }

    private func runMergeJob(id: UUID) async {
        let snapshot: MergeJob? = await MainActor.run {
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return nil }
            jobs[index].status = .running
            jobs[index].progress = max(jobs[index].progress, 0.35)
            jobs[index].detail = language == "en" ? "Lossless merging..." : "无损合并中..."
            recalculateGlobalProgress()
            return jobs[index]
        }

        guard let job = snapshot else { return }

        do {
            let merger = VideoMerger()
            try await merger.merge(files: job.files, outputURL: job.outputURL)

            await MainActor.run {
                updateJob(id: id) { item in
                    item.status = .completed
                    item.progress = 1
                    item.detail = language == "en" ? 
                        "Output complete: \(item.outputURL.lastPathComponent)" : 
                        "输出完成：\(item.outputURL.lastPathComponent)"
                }
                recalculateGlobalProgress()
            }
        } catch {
            await MainActor.run {
                updateJob(id: id) { item in
                    item.status = .failed
                    item.detail = error.localizedDescription
                }
                recalculateGlobalProgress()
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func updateJob(id: UUID, mutate: (inout MergeJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
    }

    @MainActor
    private func recalculateGlobalProgress() {
        guard !jobs.isEmpty else {
            globalProgress = 0
            return
        }

        let total = jobs.reduce(0) { partial, job in
            partial + max(0, min(1, job.progress))
        }

        globalProgress = total / Double(jobs.count)
    }

    private func resolveOutputURL(preferredBaseName: String) -> URL? {
        if let folder = defaultOutputDirectoryURL {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return uniqueOutputURL(in: folder, preferredBaseName: preferredBaseName, ext: "mov")
        }

        let panel = NSSavePanel()
        panel.title = language == "en" ? "Select output file" : "选择输出文件"
        panel.nameFieldStringValue = "\(preferredBaseName).mov"
        panel.allowedContentTypes = [.quickTimeMovie, .mpeg4Movie]

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private var defaultOutputDirectoryURL: URL? {
        guard !defaultOutputFolderPath.isEmpty else { return nil }
        return URL(fileURLWithPath: defaultOutputFolderPath, isDirectory: true)
    }

    private func uniqueOutputURL(in folder: URL, preferredBaseName: String, ext: String) -> URL {
        var candidate = folder.appendingPathComponent("\(preferredBaseName).\(ext)")
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(preferredBaseName)-\(index).\(ext)")
            index += 1
        }

        return candidate
    }

    private func sanitizeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let parts = value.components(separatedBy: invalid)
        let raw = parts.joined(separator: "_")
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Joinly_Merged" : trimmed
    }
}

struct FileDropDelegate: DropDelegate {
    let onDrop: ([URL]) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        let urls = info.itemProviders(for: [.fileURL]).compactMap { provider -> URL? in
            var url: URL?
            provider.loadObject(ofClass: URL.self) { loadedUrl, _ in
                url = loadedUrl
            }
            return url
        }
        
        onDrop(urls)
        return !urls.isEmpty
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [.fileURL]).isEmpty
    }
}

