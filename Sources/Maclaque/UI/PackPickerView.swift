import SwiftUI

struct PackPickerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 6) {
            ForEach(appState.soundPackManager?.packs ?? []) { pack in
                Button(action: {
                    appState.currentPackId = pack.id
                }) {
                    HStack(spacing: 10) {
                        Text(pack.emoji)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "F0F0F5"))
                            Text(pack.description)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "8888AA"))
                                .lineLimit(1)
                        }

                        Spacer()

                        if appState.currentPackId == pack.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "FF2A1F"))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        appState.currentPackId == pack.id
                            ? Color(hex: "FF2A1F").opacity(0.1)
                            : Color.clear
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
