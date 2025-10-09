//
//  Utilities.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import UIKit
import AVFoundation
import SwiftUI // <-- FIX IS HERE

// MARK: - Time Formatter
func formatTime(_ timeInterval: TimeInterval) -> String {
    let totalSeconds = max(0, Int(timeInterval))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    private init() {}

    func trigger(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Metronome Class
class Metronome {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    @AppStorage("metronomeBPM") private var bpm: Double = 110.0

    init() {
        setupAudioPlayer()
    }

    func start() {
        guard timer == nil else { return }
        let interval = 60.0 / bpm
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.audioPlayer?.play()
        }
        timer?.fire() // Start immediately
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
    }

    private func setupAudioPlayer() {
        let sampleRate: Double = 44100
        let frequency: Double = 880
        let duration: Double = 0.05
        let frameCount = Int(duration * sampleRate)
        var buffer = [Int16]()

        for i in 0..<frameCount {
            let value = sin(2.0 * .pi * frequency * Double(i) / sampleRate)
            buffer.append(Int16(value * Double(Int16.max)))
        }

        let headerSize = 44
        var wavData = Data(capacity: headerSize + buffer.count * 2)
        wavData.append("RIFF".data(using: .ascii)!)
        var chunkSize = UInt32(36 + buffer.count * 2).littleEndian
        wavData.append(Data(bytes: &chunkSize, count: 4))
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        var subchunk1Size: UInt32 = 16
        wavData.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: UInt16 = 1
        wavData.append(Data(bytes: &audioFormat, count: 2))
        var numChannels: UInt16 = 1
        wavData.append(Data(bytes: &numChannels, count: 2))
        var sampleRateHdr = UInt32(sampleRate).littleEndian
        wavData.append(Data(bytes: &sampleRateHdr, count: 4))
        var byteRate = UInt32(sampleRate * 2).littleEndian
        wavData.append(Data(bytes: &byteRate, count: 4))
        var blockAlign: UInt16 = 2
        wavData.append(Data(bytes: &blockAlign, count: 2))
        var bitsPerSample: UInt16 = 16
        wavData.append(Data(bytes: &bitsPerSample, count: 2))
        wavData.append("data".data(using: .ascii)!)
        var subchunk2Size = UInt32(buffer.count * 2).littleEndian
        wavData.append(Data(bytes: &subchunk2Size, count: 4))
        let pcmData = buffer.withUnsafeBufferPointer { Data(buffer: $0) }
        wavData.append(pcmData)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Metronome audio player setup failed: \(error)")
        }
    }
}
