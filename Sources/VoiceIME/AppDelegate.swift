import AppKit
import AVFoundation
import Speech

class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()
    private let fnMonitor = FnKeyMonitor()
    private let audioEngine = AudioEngine()
    private let speechRecognizer = SpeechRecognizer()
    private let capsuleWindow = CapsuleWindow()
    private let textInjector = TextInjector()
    private let llmService = LLMService()

    private var isRecording = false
    private var finalResultReceived = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()
        setupStatusBar()
        setupFnMonitor()
        setupAudioPipeline()
    }

    // MARK: - Permissions

    private func requestPermissions() {
        // Microphone
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                print("[VoiceIME] Microphone permission denied.")
            }
        }

        // Speech recognition
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("[VoiceIME] Speech recognition permission denied.")
            }
        }

        // Accessibility (for CGEvent tap)
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Setup

    private func setupStatusBar() {
        statusBar.setup()
        statusBar.onLanguageChanged = { [weak self] locale in
            self?.speechRecognizer.updateLocale(locale)
        }
    }

    private func setupFnMonitor() {
        fnMonitor.onFnDown = { [weak self] in
            self?.startRecording()
        }
        fnMonitor.onFnUp = { [weak self] in
            self?.stopRecording()
        }
        fnMonitor.start()
    }

    private func setupAudioPipeline() {
        audioEngine.onRMSLevel = { [weak self] level in
            self?.capsuleWindow.updateRMS(level)
        }
        audioEngine.onBuffer = { [weak self] buffer in
            self?.speechRecognizer.appendBuffer(buffer)
        }

        speechRecognizer.onPartialResult = { [weak self] text in
            self?.capsuleWindow.updateText(text)
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        finalResultReceived = false

        speechRecognizer.updateLocale(Settings.shared.selectedLocale)

        speechRecognizer.onFinalResult = { [weak self] text in
            guard let self = self, !self.finalResultReceived else { return }
            self.finalResultReceived = true
            self.handleFinalResult(text)
        }

        capsuleWindow.show()

        do {
            try audioEngine.start()
        } catch {
            print("[VoiceIME] Failed to start audio engine: \(error)")
            isRecording = false
            capsuleWindow.hide()
            return
        }

        speechRecognizer.start()
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        audioEngine.stop()
        speechRecognizer.stop()

        // If no final result received after stopping, wait a bit then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, !self.finalResultReceived else { return }
            self.finalResultReceived = true
            self.capsuleWindow.hide()
        }
    }

    // MARK: - Result handling

    private func handleFinalResult(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            capsuleWindow.hide()
            return
        }

        if Settings.shared.llmEnabled && Settings.shared.isLLMConfigured {
            capsuleWindow.showRefining()
            llmService.refine(trimmed) { [weak self] refined in
                self?.injectAndDismiss(refined)
            }
        } else {
            injectAndDismiss(trimmed)
        }
    }

    private func injectAndDismiss(_ text: String) {
        capsuleWindow.hide { [weak self] in
            // Small delay after capsule hides to ensure focus is back
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.textInjector.inject(text)
            }
        }
    }
}
