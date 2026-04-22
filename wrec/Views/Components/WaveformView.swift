import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let speakerRegions: [(start: Double, end: Double, color: Color)]

    @State private var playbackPosition: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Speaker regions background
                ForEach(speakerRegions.indices, id: \.self) { index in
                    let region = speakerRegions[index]
                    let startX = CGFloat(region.start / totalDuration) * geometry.size.width
                    let width = CGFloat((region.end - region.start) / totalDuration) * geometry.size.width

                    Rectangle()
                        .fill(region.color.opacity(0.2))
                        .frame(width: width)
                        .offset(x: startX)
                }

                // Waveform
                WaveformShape(samples: samples)
                    .stroke(Color.accentColor, lineWidth: 1)

                // Playback position indicator
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2)
                    .offset(x: CGFloat(playbackPosition / max(totalDuration, 1)) * geometry.size.width)
            }
        }
        .frame(height: 60)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var totalDuration: Double {
        speakerRegions.map { $0.end }.max() ?? 1
    }
}

struct WaveformShape: Shape {
    let samples: [Float]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        guard samples.count > 1 else { return path }

        let step = rect.width / CGFloat(samples.count - 1)
        let midY = rect.midY
        let amplitude = rect.height / 2

        path.move(to: CGPoint(x: 0, y: midY))

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * step
            let y = midY - CGFloat(sample) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}
