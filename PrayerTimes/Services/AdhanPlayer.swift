import Foundation
import AVFoundation

class AdhanPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?

    var volume: Float {
        get { UserDefaults.standard.float(forKey: "adhanVolume") }
        set {
            UserDefaults.standard.set(newValue, forKey: "adhanVolume")
            player?.volume = newValue
        }
    }

    override init() {
        super.init()
        if UserDefaults.standard.object(forKey: "adhanVolume") == nil {
            UserDefaults.standard.set(Float(0.8), forKey: "adhanVolume")
        }
    }

    func play() {
        guard !isPlaying else { return }

        guard let url = Bundle.main.url(forResource: "adhan", withExtension: "mp3") else {
            print("adhan mp3 not found in bundle")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.volume = volume
            player?.play()
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        } catch {
            print("Failed to play adhan: \(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}

extension AdhanPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
