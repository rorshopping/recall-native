import Foundation
import PDFKit
import Vision
import UIKit

struct DocumentImportService: Sendable {
    private static let maxPDFPages = 20

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
        guard document.pageCount <= Self.maxPDFPages else { throw ImportError.tooManyPages }

        // Process each page independently. Real-world PDFs often mix a text
        // layer with scanned pages, so falling back to OCR only when the whole
        // document has no selectable text silently loses scanned pages.
        var pages: [String] = []
        pages.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }

            let selectableText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !selectableText.isEmpty {
                pages.append(selectableText)
                continue
            }

            let image = page.thumbnail(
                of: CGSize(width: 1800, height: 2400),
                for: .mediaBox
            )
            if let text = try? extractImageText(from: image), !text.isEmpty {
                pages.append(text)
            }
        }

        let text = pages.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ImportError.emptyPDF }
        return text
    }

    private func extractImageText(from image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else { throw ImportError.invalidImage }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Prefer the user's language but allow English as a common second
        // language for lecture slides and technical material. Language detection
        // remains enabled so multilingual images are handled more gracefully.
        let preferredLanguage = Locale.current.language.languageCode?.identifier
        var languages: [String] = []
        if let preferredLanguage, !preferredLanguage.isEmpty {
            languages.append(preferredLanguage)
        }
        if !languages.contains("en") {
            languages.append("en")
        }
        request.recognitionLanguages = languages
        request.automaticallyDetectsLanguage = true

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
            case .tooManyPages: return "Please choose a PDF with \(DocumentImportService.maxPDFPages) pages or fewer."
            case .emptyPDF: return "No readable text was found in this PDF."
            case .invalidImage: return "The selected image could not be read."
            case .emptyImage: return "No readable text was found in this image."
            }
        }
    }
}
