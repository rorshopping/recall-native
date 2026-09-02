import Foundation
import PDFKit
import Vision
import UIKit

struct DocumentImportService: Sendable {
    func extractText(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let type = url.pathExtension.lowercased()
        if type == "pdf" { return try extractPDFText(from: url) }
        if let image = UIImage(contentsOfFile: url.path) { return try extractImageText(from: image) }
        throw ImportError.invalidDocument
    }

    private func extractPDFText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else { throw ImportError.invalidPDF }
        guard document.pageCount <= 5 else { throw ImportError.tooManyPages }
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ImportError.emptyPDF }
        return text
    }

    private func extractImageText(from image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else { throw ImportError.invalidImage }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.current.language.languageCode?.identifier ?? "en"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ImportError.emptyImage }
        return text
    }

    enum ImportError: LocalizedError {
        case invalidDocument
        case invalidPDF
        case tooManyPages
        case emptyPDF
        case invalidImage
        case emptyImage

        var errorDescription: String? {
            switch self {
            case .invalidDocument: return "The selected document could not be read."
            case .invalidPDF: return "The selected PDF could not be read."
            case .tooManyPages: return "Please choose a PDF with 5 pages or fewer."
            case .emptyPDF: return "This PDF does not contain selectable text."
            case .invalidImage: return "The selected image could not be read."
            case .emptyImage: return "No readable text was found in this image."
            }
        }
    }
}
