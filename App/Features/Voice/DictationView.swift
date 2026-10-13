import SwiftUI

/// "Plan my day": the user describes their errands out loud, then reviews them.
struct DictationView: View {
    var onAdded: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = DictationRecorder()
    @State private var reviewText: String?
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("What do you need to do today?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                // Fills in as you speak, and can be typed into or corrected.
                TextField(
                    "For example: “Stop at CVS for my prescription, do the grocery shopping, and pick up the kids at 3.”",
                    text: $text,
                    axis: .vertical
                )
                .font(.title3)
                .lineLimit(4...10)
                .frame(maxHeight: .infinity, alignment: .top)
                .onChange(of: recorder.transcript) { _, newValue in text = newValue }

                if recorder.isRecording {
                    Label("Listening…", systemImage: "waveform")
                        .foregroundStyle(.secondary)
                }

                if let error = recorder.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }

                Button {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        Task { await recorder.start(keeping: text) }
                    }
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 72))
                        .symbolEffect(.pulse, isActive: recorder.isRecording)
                }
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")

                Button("Plan it") {
                    recorder.stop()
                    reviewText = text
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.stop()
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $reviewText) { text in
                VoiceReviewView(text: text, onAdded: {
                    onAdded()
                    dismiss()
                })
            }
            .task { await recorder.start() }
        }
    }
}
