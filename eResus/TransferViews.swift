//
//  TransferViews.swift
//  eResus
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import VisionKit

struct SessionTransferModal: View {
    @ObservedObject var viewModel: ArrestViewModel
    @State private var hostedCode: String? = nil
    @State private var isHosting = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Transfer Arrest")
                .font(.title2).bold()
            
            if let state = viewModel.generateTransferState() {
                // iOS to iOS AirDrop Native
                ShareLink(item: state, preview: SharePreview("eResus Active Session")) {
                    HStack {
                        Image(systemName: "airdrop")
                        Text("AirDrop to iPhone/iPad")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            Divider()
            
            if isHosting {
                ProgressView("Preparing Transfer...")
            } else if let code = hostedCode {
                Text("Scan on receiving device:")
                    .font(.headline)
                
                Image(uiImage: generateQRCode(from: code))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                
                Text("Code: \(code)")
                    .font(.system(.title, design: .monospaced)).bold()
            } else {
                Button {
                    isHosting = true
                    if let state = viewModel.generateTransferState() {
                        FirebaseManager.shared.hostSessionTransfer(state: state) { id in
                            hostedCode = id
                            isHosting = false
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "qrcode")
                        Text("Generate QR Code (Cross-Platform)")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .presentationDetents([.medium])
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage, let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        }
        return UIImage()
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIViewController {
        if #available(iOS 16.0, *) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                let scanner = DataScannerViewController(
                    recognizedDataTypes: [.barcode(symbologies: [.qr])],
                    qualityLevel: .fast,
                    recognizesMultipleItems: false,
                    isHighFrameRateTrackingEnabled: false,
                    isHighlightingEnabled: true
                )
                scanner.delegate = context.coordinator as? DataScannerViewControllerDelegate
                try? scanner.startScanning()
                return scanner
            }
        }
        
        // Fallback for Simulator or unsupported devices
        let fallbackVC = UIViewController()
        let label = UILabel()
        label.text = "QR Scanner requires a physical device running iOS 16+"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        fallbackVC.view.addSubview(label)
        fallbackVC.view.backgroundColor = .systemBackground
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: fallbackVC.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: fallbackVC.view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: fallbackVC.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: fallbackVC.view.trailingAnchor, constant: -20)
        ])
        
        return fallbackVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject {
        var parent: QRScannerView
        init(_ parent: QRScannerView) { self.parent = parent }
    }
}

@available(iOS 16.0, *)
extension QRScannerView.Coordinator: DataScannerViewControllerDelegate {
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        if let item = addedItems.first, case .barcode(let barcode) = item {
            parent.scannedCode = barcode.payloadStringValue
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
