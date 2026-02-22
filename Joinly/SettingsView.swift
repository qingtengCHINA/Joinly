import SwiftUI

struct SettingsView: View {
    @AppStorage("language") private var language: String = "zh"
    @AppStorage("defaultOutputFolderPath") private var defaultOutputFolderPath = ""
    @AppStorage("maxParallelJobs") private var maxParallelJobs = 2

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(language == "en" ? "Settings" : "设置")
                        .font(.system(size: 28, weight: .semibold))

                    // 语言选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == "en" ? "Language" : "语言")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Picker(language == "en" ? "Language" : "语言", selection: $language) {
                            Text("中文").tag("zh")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    sectionHeader(language == "en" ? "About" : "软件说明")
                    Text("Joinly 是一款专注无损拼接的视频工具。你可以把多个短视频按顺序组合成一个完整视频，不压缩、不降画质；支持多组任务并发处理，适合日常素材整理与批量导出。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    sectionHeader(language == "en" ? "Merge Settings" : "合并设置")

                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == "en" ? "Default Output Location" : "默认输出位置")
                            .font(.system(size: 13, weight: .medium))

                        Text(defaultOutputFolderPath.isEmpty ? (language == "en" ? "Not Set" : "未设置") : defaultOutputFolderPath)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(defaultOutputFolderPath.isEmpty ? .secondary : .primary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 10) {
                        Button(language == "en" ? "Set Location" : "设置位置", action: chooseDefaultOutputFolder)
                            .buttonStyle(.borderedProminent)

                        Button(language == "en" ? "Clear" : "清除") {
                            defaultOutputFolderPath = ""
                        }
                        .buttonStyle(.bordered)
                        .disabled(defaultOutputFolderPath.isEmpty)
                    }

                    HStack {
                        Stepper(language == "en" ? "Concurrent Jobs: \(maxParallelJobs)" : "并发任务数：\(maxParallelJobs)", value: $maxParallelJobs, in: 1...6)
                        Spacer()
                    }

                    Divider()

                    sectionHeader(language == "en" ? "Support & Links" : "支持与链接")
                    settingsLinkRow(title: language == "en" ? "Privacy Policy" : "隐私声明", url: "https://www.freeprivacypolicy.com/live/ead0ec08-f1a2-4b2e-8260-799065a2dfac")
                    settingsLinkRow(title: language == "en" ? "Contact Developer" : "联系开发者", url: "https://qingtengstudio.com/")
                    settingsLinkRow(title: language == "en" ? "Buy Me a Coffee" : "请喝杯咖啡", url: "https://buymeacoffee.com/qingteng")

                    Spacer(minLength: 16)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            VStack(spacing: 3) {
                Text(AppMetadata.madeBy)
                    .font(.system(size: 12, weight: .semibold))
                Text(AppMetadata.versionDisplay)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
    }

    private func settingsLinkRow(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chooseDefaultOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = language == "en" ? "Select Default Output Directory" : "选择默认输出目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            defaultOutputFolderPath = url.path
        }
    }
}
