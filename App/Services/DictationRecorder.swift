import Foundation
import AVFoundation
import Speech
import Observation

/// Records the user's voice and transcribes it live, on device where supported.
@MainActor
@Observable
final class DictationRecorder {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        errorMessage = nil
        guard await Self.requestSpeechPermission() else {
            errorMessage = "Allow speech recognition in Settings to plan by voice."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = "Allow microphone access in Settings to plan by voice."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now. You can type instead."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            #if targetEnvironment(simulator)
            // The simulator often lacks on-device speech models.
            request.requiresOnDeviceRecognition = false
            #else
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            #endif
            self.request = request

            guard Self.installTap(on: audioEngine.inputNode, feeding: request) else {
                errorMessage = "No microphone found. You can type instead."
                try? session.setActive(false)
                return
            }
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            task = Self.recognize(with: recognizer, request: request) { [weak self] text, finished, failed in
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if failed, self.transcript.isEmpty {
                        self.errorMessage = "Couldn't hear anything. Check the microphone, or type instead."
                    }
                    if finished { self.stop() }
                }
            }
        } catch {
            errorMessage = "Couldn't start recording. You can type instead."
            stop()
        }
    }

    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // The audio tap and recognition callbacks run on background threads, so they are
    // created outside the main actor to avoid Swift 6 isolation checks trapping at runtime.

    /// Returns false when there is no usable microphone input.
    private nonisolated static func installTap(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) -> Bool {
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return false }
        // The request is documented as safe to append to from the audio thread.
        nonisolated(unsafe) let request = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        return true
    }

    private nonisolated static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (_ text: String?, _ finished: Bool, _ failed: Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false), error != nil)
        }
    }

    private nonisolated static func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
