import SwiftUI

/// "Plan my day": the user describes their errands out loud, then reviews them.
struct DictationView: View {
    var onAdded: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = DictationRecorder()
    @State private var reviewText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("What do you need to do today?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                ScrollView {
                    Text(recorder.transcript.isEmpty ? "For example: “Stop at CVS for my prescription, do the grocery shopping, and pick up the kids at 3.”" : recorder.transcript)
                        .font(.title3)
                        .foregroundStyle(recorder.transcript.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = recorder.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }

                Button {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        Task { await recorder.start() }
                    }
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 72))
                        .symbolEffect(.pulse, isActive: recorder.isRecording)
                }
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")

                Button("Plan it") {
                    recorder.stop()
                    reviewText = recorder.transcript
                }
                .buttonStyle(.borderedProminent)
                .disabled(recorder.transcript.trimmingCharacters(in: .whitespaces).isEmpty)
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
