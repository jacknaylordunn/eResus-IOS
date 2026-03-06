//
//  Utilities.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import SwiftUI
import AVFoundation

// MARK: - Time Formatter
struct TimeFormatter {
    static func format(_ timeInterval: TimeInterval) -> String {
        let time = max(0, timeInterval)
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Haptic Manager
struct HapticManager {
    static let shared = HapticManager()
    private init() {}
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Metronome Mode
enum MetronomeMode {
    case general
    case nls
}

// MARK: - Metronome
@MainActor
class Metronome: ObservableObject {
    @Published var isMetronomeOn = false
    var mode: MetronomeMode = .general
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    init() {
        setupAudioSession()
        prepareAudioPlayer()
    }

    private func setupAudioSession() {
        do {
            // Use mixWithOthers to prevent interruptions and duckOthers to soften other audio.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
    }

    private func prepareAudioPlayer() {
        let sampleRate = 44100.0
        let duration = 0.1 // Increased duration for a softer sound
        let frameCount = Int(duration * sampleRate)
        let channels = 1
        let bitsPerSample = 16
        
        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(int32: Int32(36 + frameCount * channels * bitsPerSample / 8))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(int32: 16)
        data.append(int16: 1)
        data.append(int16: Int16(channels))
        data.append(int32: Int32(sampleRate))
        data.append(int32: Int32(sampleRate * Double(channels * bitsPerSample / 8)))
        data.append(int16: Int16(channels * bitsPerSample / 8))
        data.append(int16: Int16(bitsPerSample))
        data.append("data".data(using: .ascii)!)
        data.append(int32: Int32(frameCount * channels * bitsPerSample / 8))

        // Generate a sine wave with a fade-out to prevent clicking
        let frequency = 880.0
        for i in 0..<frameCount {
            let progress = Double(i) / Double(frameCount)
            let envelope = 1.0 - progress // Linear fade-out
            
            let value = sin(2.0 * .pi * frequency * Double(i) / sampleRate) * envelope
            let sample = Int16(value * Double(Int16.max))
            data.append(int16: sample)
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error setting up metronome audio: \(error.localizedDescription)")
        }
    }
    
    func toggle() {
        isMetronomeOn.toggle()
        if isMetronomeOn {
            start()
        } else {
            stop()
        }
    }
    
    func turnOff() {
        if isMetronomeOn {
            isMetronomeOn = false
            stop()
        }
    }

    private func start() {
        stop()
        
        if mode == .general {
            let interval = 60.0 / Double(AppSettings.metronomeBPM)
            
            let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                self?.playSound()
            }
            RunLoop.main.add(newTimer, forMode: .common)
            self.timer = newTimer
            newTimer.fire()
            
        } else if mode == .nls {
            // NLS 3:1 Ratio Mode (182bpm = 0.33s intervals)
            var step = 0
            let interval = 0.333333
            
            let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Beats 0, 1, 2 play a sound. Beats 3, 4, 5 are silent (1 second total pause for ventilation)
                if step < 3 {
                    self.playSound()
                }
                
                step += 1
                if step >= 6 {
                    step = 0
                }
            }
            RunLoop.main.add(newTimer, forMode: .common)
            self.timer = newTimer
            newTimer.fire()
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func playSound() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}


// MARK: - Data Extensions
extension Data {
    mutating func append<T>(int: T) where T: FixedWidthInteger {
        var value = int.littleEndian
        Swift.withUnsafeBytes(of: &value) {
            append(contentsOf: $0)
        }
    }
    
    mutating func append(int32 value: Int32) {
        append(int: value)
    }

    mutating func append(int16 value: Int16) {
        append(int: value)
    }
}
