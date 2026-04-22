import Foundation
import AppKit
import PDFKit

final class PDFGenerator {
    func generatePdf(for meeting: Meeting, to url: URL) throws -> URL {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "wrec" as CFString,
            kCGPDFContextAuthor: "wrec" as CFString,
            kCGPDFContextTitle: meeting.title as CFString
        ]

        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let pdfContext = CGContext(url as CFURL, mediaBox: &pageRect, pdfMetaData as CFDictionary) else {
            throw PDFGeneratorError.contextCreationFailed
        }

        var yPosition: CGFloat = pageHeight - margin

        pdfContext.beginPage(mediaBox: nil)

        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]

        let titleString = meeting.title as NSString
        titleString.draw(at: CGPoint(x: margin, y: yPosition - 30), withAttributes: titleAttributes)
        yPosition -= 50

        // Metadata
        let metaFont = NSFont.systemFont(ofSize: 12)
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: NSColor.darkGray
        ]

        let metaLines = [
            "Type: \(meeting.meetingType.rawValue)",
            "Date: \(meeting.actualStartTime?.formatted() ?? "Unknown")",
            "Duration: \(meeting.formattedDuration)"
        ]

        for line in metaLines {
            let lineString = line as NSString
            lineString.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metaAttributes)
            yPosition -= 18
        }

        yPosition -= 30

        // Divider line
        pdfContext.setStrokeColor(NSColor.gray.cgColor)
        pdfContext.setLineWidth(0.5)
        pdfContext.move(to: CGPoint(x: margin, y: yPosition))
        pdfContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
        pdfContext.strokePath()
        yPosition -= 30

        // Transcript
        let transcriptFont = NSFont.systemFont(ofSize: 11)
        let speakerFont = NSFont.boldSystemFont(ofSize: 11)

        let transcriptAttributes: [NSAttributedString.Key: Any] = [
            .font: transcriptFont,
            .foregroundColor: NSColor.black
        ]

        let speakerAttributes: [NSAttributedString.Key: Any] = [
            .font: speakerFont,
            .foregroundColor: NSColor.darkGray
        ]

        for segment in meeting.segments.sorted(by: { $0.startTime < $1.startTime }) {
            if yPosition < margin + 100 {
                pdfContext.endPage()
                var newPageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                pdfContext.beginPage(mediaBox: nil)
                yPosition = pageHeight - margin
            }

            let speakerText = "[\(segment.formattedStartTime)] \(segment.speakerLabel):"
            let speakerString = speakerText as NSString
            speakerString.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: speakerAttributes)
            yPosition -= 16

            let textString = segment.text as NSString
            let textBounds = textString.boundingRect(
                with: CGSize(width: pageWidth - 2 * margin, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: transcriptAttributes,
                context: nil
            )
            textString.draw(in: CGRect(x: margin, y: yPosition - textBounds.height, width: pageWidth - 2 * margin, height: textBounds.height + 20), withAttributes: transcriptAttributes)
            yPosition -= textBounds.height + 24
        }

        pdfContext.endPage()
        pdfContext.closePDF()

        return url
    }
}

enum PDFGeneratorError: Error {
    case contextCreationFailed
}
