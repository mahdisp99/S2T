import AVFoundation
import Foundation

// MARK: - Audio Recorder
class AudioRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var converter: AVAudioConverter?
    private var onAudioData: ((Data) -> Void)?
    private var onLevelUpdate: ((Float) -> Void)?
    private var levelSmoother: Float = 0
    
    func startRecording(onAudioData: @escaping (Data) -> Void, onLevelUpdate: ((Float) -> Void)? = nil) {
        self.onAudioData = onAudioData
        self.onLevelUpdate = onLevelUpdate
        self.levelSmoother = 0
        
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let inputNode = inputNode else {
            print("⚠️  خطا: میکروفون پیدا نشد")
            return
        }
        
        // گرفتن format واقعی میکروفون
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // تنظیمات output format (16kHz, mono) برای Soniox
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Config.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("⚠️  خطا: نمی‌تونم output format بسازم")
            return
        }
        
        // ساخت converter
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            print("⚠️  خطا: نمی‌تونم converter بسازم")
            return
        }
        self.converter = converter
        
        // Install tap با format میکروفون (نه output format!)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let converter = self.converter else { return }
            
            // تبدیل به 16kHz
            let convertedBuffer = self.convertBuffer(buffer, using: converter, to: outputFormat)
            
            if let convertedBuffer = convertedBuffer {
                self.processLevel(from: convertedBuffer)
                // تبدیل AVAudioPCMBuffer به Data
                let audioData = self.bufferToData(convertedBuffer)
                self.onAudioData?(audioData)
            }
        }
        
        do {
            try audioEngine?.start()
            print("✅ ضبط صدا شروع شد")
            print("   Input: \(inputFormat.sampleRate)Hz → Output: \(outputFormat.sampleRate)Hz")
        } catch {
            print("⚠️  خطا در شروع ضبط: \(error)")
        }
    }
    
    func stopRecording() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        converter = nil
        print("⏸️ ضبط صدا متوقف شد")
        onLevelUpdate?(0)
        onLevelUpdate = nil
        onAudioData = nil
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // محاسبه تعداد frame های output
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("⚠️  خطا در convert: \(error)")
            return nil
        }
        
        return convertedBuffer
    }
    
    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        return Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
    
    private func processLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData?.pointee else {
            DispatchQueue.main.async { [weak self] in
                self?.onLevelUpdate?(0)
            }
            return
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        var sumSquares: Float = 0
        for index in 0..<frameLength {
            let sample = Float(channelData[index]) / Float(Int16.max)
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frameLength))
        // کمی smooth برای جلوگیری از پرش
        let smoothingFactor: Float = 0.2
        levelSmoother = (rms * smoothingFactor) + (levelSmoother * (1 - smoothingFactor))
        let normalized = min(max(levelSmoother * 4.0, 0), 1)
        
        DispatchQueue.main.async { [weak self] in
            self?.onLevelUpdate?(normalized)
        }
    }
}
