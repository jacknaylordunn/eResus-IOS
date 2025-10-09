//
//  PDFKitView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import PDFKit

// This view is a wrapper around PDFKit's PDFView to make it usable in SwiftUI.
struct PDFKitView: UIViewRepresentable {
    let pdfName: String

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        
        // Load the PDF from the app's main bundle.
        if let url = Bundle.main.url(forResource: pdfName, withExtension: "pdf") {
            pdfView.document = PDFDocument(url: url)
        }
        
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // We don't need to update the view in this case.
    }
}

// A simple view to host the PDF viewer within a sheet.
struct PDFViewer: View {
    let pdfName: String
    let title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            PDFKitView(pdfName: pdfName)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
