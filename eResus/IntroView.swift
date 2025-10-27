import SwiftUI

struct IntroView: View {
    /// This binding is used to dismiss the view when the user is done.
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Welcome to eResus!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white, .red)
                .symbolRenderingMode(.palette)
                .padding()

            VStack(alignment: .leading, spacing: 25) {
                FeatureView(
                    iconName: "waveform.path.ecg",
                    title: "Real-time Arrest Management",
                    description: "Manage cardiac arrest events with a real-time timer, metronome, and event logger."
                )
                FeatureView(
                    iconName: "book.closed.fill",
                    title: "Comprehensive Logbook",
                    description: "Automatically record all actions for review, debriefing, and documentation."
                )
                FeatureView(
                    iconName: "doc.text.magnifyingglass",
                    title: "Integrated Guidelines",
                    description: "Access essential resuscitation guidelines and drug information instantly when you need them."
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button("Get Started") {
                // When tapped, this sets the binding to false, dismissing the sheet.
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom)
        }
    }
}

/// A helper view to display a single feature with an icon, title, and description.
struct FeatureView: View {
    let iconName: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 50)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    IntroView(isPresented: .constant(true))
}
