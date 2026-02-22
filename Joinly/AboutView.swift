import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                    Color(red: 0.88, green: 0.93, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

                Text("Joinly")
                    .font(.custom("AvenirNext-Heavy", size: 28))

                VStack(spacing: 6) {
                    infoLine("开发日期", AppMetadata.developmentDate)
                    infoLine("作者", "QingTengStudio")
                    infoLine("版本", AppMetadata.versionDisplay)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(26)
            .frame(width: 380, height: 420)
        }
    }

    private func infoLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.custom("AvenirNext-Medium", size: 13))
    }
}
