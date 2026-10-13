import Foundation
import AVFoundation
import Speech
import Observation

/// Records the user's voice and transcribes it live, on device where supported.
///
/// Speech recognition ends a session after a pause, and after about a minute,
/// and then starts its text over. The recorder keeps what was already heard and
/// starts a new session, so it keeps listening until the user taps stop.
@MainActor
@Observable
final class DictationRecorder {
    var transcript: String {
        [heard, current].filter { !$0.isEmpty }.joined(separator: " ")
    }
    private(set) var isRecording = false
    private(set) var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Text from earlier recognition sessions in this recording.
    private var heard = ""
    /// Text from the session in progress.
    private var current = ""
    /// Sessions in a row that ended in an error without hearing anything.
    private var silentFailures = 0

    /// Starts listening. New speech is added after `existing`, such as text
    /// the user already said or typed.
    func start(keeping existing: String = "") async {
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

        heard = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        current = ""
        silentFailures = 0
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            guard audioEngine.inputNode.outputFormat(forBus: 0).sampleRate > 0 else {
                errorMessage = "No microphone found. You can type instead."
                try? session.setActive(false)
                return
            }
            isRecording = true
            beginSession(with: recognizer)
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "Couldn't start recording. You can type instead."
            stop()
        }
    }

    /// Starts a recognition session fed by the microphone.
    private func beginSession(with recognizer: SFSpeechRecognizer) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        #if targetEnvironment(simulator)
        // The simulator often lacks on-device speech models.
        request.requiresOnDeviceRecognition = false
        #else
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        #endif
        self.request = request

        let input = audioEngine.inputNode
        input.removeTap(onBus: 0)
        Self.installTap(on: input, feeding: request)

        let session = ObjectIdentifier(request)
        task = Self.recognize(with: recognizer, request: request) { [weak self] text, finished, failed in
            Task { @MainActor in
                // Ignore late results from a session that has been replaced.
                guard let self, let current = self.request, ObjectIdentifier(current) == session else { return }
                self.handle(text: text, finished: finished, failed: failed)
            }
        }
    }

    private func handle(text: String?, finished: Bool, failed: Bool) {
        if let text, !text.isEmpty {
            // Some recognisers start their text over after a pause without ending
            // the session. Keep the earlier words when that happens.
            if Self.startedOver(previous: current, next: text) { commitCurrent() }
            current = text
            silentFailures = 0
        }
        guard finished, isRecording else { return }

        // The session ended (a pause, the time limit, or silence): keep the
        // words and listen again, unless recognition keeps failing outright.
        if failed && current.isEmpty {
            silentFailures += 1
            if silentFailures >= 10 || (silentFailures >= 3 && heard.isEmpty) {
                if heard.isEmpty {
                    errorMessage = "Couldn't hear anything. Check the microphone, or type instead."
                }
                stop()
                return
            }
        }
        commitCurrent()
        task?.cancel()
        guard let recognizer else { return stop() }
        beginSession(with: recognizer)
    }

    private func commitCurrent() {
        guard !current.isEmpty else { return }
        heard = transcript
        current = ""
    }

    /// True when `next` is a new utterance rather than a revision of `previous`.
    nonisolated static func startedOver(previous: String, next: String) -> Bool {
        guard !previous.isEmpty, next.count < previous.count else { return false }
        func firstWord(_ text: String) -> String {
            String((text.split(separator: " ").first ?? "").lowercased().filter(\.isLetter))
        }
        return firstWord(previous) != firstWord(next)
    }

    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        // The final words still arrive after this and are kept.
        request?.endAudio()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // The audio tap and recognition callbacks run on background threads, so they are
    // created outside the main actor to avoid Swift 6 isolation checks trapping at runtime.

    private nonisolated static func installTap(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        // The request is documented as safe to append to from the audio thread.
        nonisolated(unsafe) let request = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
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
