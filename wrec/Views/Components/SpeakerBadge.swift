import SwiftUI

struct SpeakerBadge: View {
    let label: String
    let isMe: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .fontWeight(isMe ? .semibold : .regular)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(4)
    }

    private var badgeColor: Color {
        if isMe {
            return .blue
        } else {
            let colors: [Color] = [.green, .orange, .purple, .pink, .teal, .indigo]
            let hash = label.hashValue
            return colors[abs(hash) % colors.count]
        }
    }
}
