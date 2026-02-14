import Foundation
import AVFoundation

class AdhanPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?

    func play() {
        guard !isPlaying else { return }

        guard let url = Bundle.main.url(forResource: "adhan", withExtension: "mp3") else {
            print("adhan mp3 not found in bundle")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
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
