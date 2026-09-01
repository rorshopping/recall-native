import Foundation
import PDFKit

struct DocumentImportService: Sendable {
    func extractText(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        guard let document = PDFDocument(url: url) else {
            throw ImportError.invalidPDF
        }
        guard document.pageCount <= 5 else {
            throw ImportError.tooManyPages
        }

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw ImportError.emptyPDF }
        return text
    }

    enum ImportError: LocalizedError {
        case invalidPDF
        case tooManyPages
        case emptyPDF

        var errorDescription: String? {
            switch self {
            case .invalidPDF: return "The selected PDF could not be read."
            case .tooManyPages: return "Please choose a PDF with 5 pages or fewer."
            case .emptyPDF: return "This PDF does not contain selectable text."
            }
        }
    }
}
