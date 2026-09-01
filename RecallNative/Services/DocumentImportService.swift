import Foundation
import PDFKit

struct DocumentImportService {
    func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.invalidPDF
        }
        var text = ""
        for index in 0..<min(document.pageCount, 5) {
            text += document.page(at: index)?.string ?? ""
            text += "\n"
        }
        return text
    }

    enum ImportError: LocalizedError {
        case invalidPDF
        var errorDescription: String? { "The selected PDF could not be read." }
    }
}
