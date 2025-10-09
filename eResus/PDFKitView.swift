//
//  PDFKitView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import PDFKit

// A SwiftUI view that wraps UIKit's PDFView
struct PDFKitView: UIViewRepresentable {
    let pdfName: String

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        
        // Load the PDF from the app's main bundle
        guard let url = Bundle.main.url(forResource: pdfName, withExtension: "pdf") else {
            // This will now display an error message directly in the view if the PDF isn't found
            // This is most likely due to the "Target Membership" issue.
            let errorLabel = UILabel()
            errorLabel.text = "Error: PDF file '\(pdfName).pdf' not found. Please check Target Membership in Xcode."
            errorLabel.textAlignment = .center
            errorLabel.numberOfLines = 0
            pdfView.addSubview(errorLabel)
            errorLabel.frame = pdfView.bounds
            errorLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            return pdfView
        }
        
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // No update logic needed for this static view
    }
}

