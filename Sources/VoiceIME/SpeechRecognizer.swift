import Speech

class SpeechRecognizer {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?

    init() {
        updateLocale(Settings.shared.selectedLocale)
    }

    func updateLocale(_ identifier: String) {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
    }

    func start() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("[VoiceIME] Speech recognizer not available for locale: \(Settings.shared.selectedLocale)")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.onFinalResult?(text)
                } else {
                    self.onPartialResult?(text)
                }
            }
            if let error = error {
                // Error code 1 = "no speech detected", not a real error
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1 {
                    self.onFinalResult?("")
                } else {
                    print("[VoiceIME] Speech recognition error: \(error.localizedDescription)")
                    self.onFinalResult?("")
                }
            }
        }
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stop() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
