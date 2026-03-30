import AVFoundation

class AudioEngine {
    let audioEngine = AVAudioEngine()
    var onRMSLevel: ((Float) -> Void)?
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    func start() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(max(frameLength, 1)))
            let normalized = min(1.0, rms * 10.0)
            DispatchQueue.main.async {
                self?.onRMSLevel?(normalized)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
}
