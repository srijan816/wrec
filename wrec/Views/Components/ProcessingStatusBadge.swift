import SwiftUI

struct ProcessingStatusBadge: View {
    let status: ProcessingStatus
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            Text(label)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.secondary)
        case .inProgress:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:
            return Color.secondary.opacity(0.1)
        case .inProgress:
            return Color.blue.opacity(0.1)
        case .completed:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.1)
        }
    }
}
