import SwiftUI

struct AirwayAdjunctModal: View {
    @Binding var isPresented: Bool
    let onConfirm: (AirwayAdjunctType) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Airway Adjunct")
                .font(.title2).bold()
            
            Text("Choose the type of advanced airway placed.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button { select(.sga) } label: {
                Text(AirwayAdjunctType.sga.displayName)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(.blue)
            
            Button { select(.ett) } label: {
                Text(AirwayAdjunctType.ett.displayName)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(.indigo)
            
            Button { select(.unspecified) } label: {
                Text("Unspecified")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(.gray)
            
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .presentationDetents([.height(360)])
    }
    
    private func select(_ type: AirwayAdjunctType) {
        onConfirm(type)
        isPresented = false
    }
}
