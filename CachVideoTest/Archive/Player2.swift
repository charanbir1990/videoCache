//
//  Player.swift
//  Mearging
//
//  Created by Charanbir sandhu on 07/07/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//https://developer.apple.com/documentation/avfoundation/avplayeritem/1386960-playbackbufferempty?language=objc

import UIKit
import AVKit


enum WhichPlayer {
    case current
    case next
    case previous
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}

extension AVAsset{
    func videoSize()->CGSize{
        let tracks = self.tracks(withMediaType: AVMediaType.video)
        if (tracks.count > 0){
            let videoTrack = tracks[0]
            let size = videoTrack.naturalSize
            let txf = videoTrack.preferredTransform
            let realVidSize = size.applying(txf)
            return realVidSize
        }
        return CGSize(width: 0, height: 0)
    }

}

class Player2: UIView {
    var identifire: WhichPlayer = .current
    weak var currentPlayer: Player? {
        didSet {
            if currentPlayer == self {
                identifire = .current
            }
        }
    }
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var asset: AVAsset?
    var playerLayer: AVPlayerLayer?

    
    var timer: RepeatingTimer?
    let setBufferTime = Double(1)
    var isPlay = false {
        didSet {
            isPlayOrStop()
        }
    }
    var currentDuration: Double = 0.0
    var duration: TimeInterval = 0.0
    var buffereSeconds: Double = 0.0 {
        didSet {
            isPlayOrStop()
        }
    }
    var durationObserver: NSKeyValueObservation?
    var strUrl: String? {
        didSet {
            if let strUrl = strUrl?.replacingOccurrences(of: " ", with: "%20") {
                if let url = URL(string: strUrl) {
                    setPlayer(url: url)
                }
            }
        }
    }
    
    var availableDuration: Double {
        guard let timeRange = player?.currentItem?.loadedTimeRanges.first?.timeRangeValue else {
            return 0.0
        }
        let startSeconds = timeRange.start.seconds
        let durationSeconds = timeRange.duration.seconds
        return startSeconds + durationSeconds
    }
    
    func addPreodicTimer() {
        timer = RepeatingTimer(timeInterval: 0.5)
        timer?.eventHandler = {[weak self]()in
            DispatchQueue.main.sync {
                self?.refreshBuffered()
            }
        }
        timer?.resume()
    }
    
    private func refreshBuffered() {
        currentDuration = /player?.currentTime().seconds
        buffereSeconds = Double(availableDuration - currentDuration)
    }
    
    private func isPlayOrStop() {
//        printLog(buffereSeconds, "--\(identifire)--\(self)")
        switch identifire {
        case .current:
            printLog(buffereSeconds)
            break
        case .next:
            if currentPlayer != self, currentPlayer != nil {
                if (/currentPlayer?.availableDuration == /currentPlayer?.duration && /currentPlayer?.duration > 0) {
                    if player?.currentItem == nil {
                        player?.replaceCurrentItem(with: playerItem)
                    }
                } else if /currentPlayer?.buffereSeconds > setBufferTime+5 {
                    if player?.currentItem == nil {
                        player?.replaceCurrentItem(with: playerItem)
                    }
                }else if player?.currentItem != nil {
                    player?.replaceCurrentItem(with: nil)
                }
            }
        case .previous:
            if player?.currentItem != nil {
                player?.replaceCurrentItem(with: nil)
            }
            return
        }
        if isPlay, ((availableDuration == duration && duration > 0) || buffereSeconds > setBufferTime) {
            if !(/player?.isPlaying) {
                player?.play()
            }
            if let cell = superview?.superview?.superview as? HomeTableViewCell {
                cell.progress.progress = 1
                cell.progress.isHidden = true
                cell.indicator.stopAnimating()
            }
        } else {
            if /player?.isPlaying {
                player?.pause()
            }
            if let cell = superview?.superview?.superview as? HomeTableViewCell {
                cell.progress.isHidden = false
                var val = Float(buffereSeconds/setBufferTime)
                if (availableDuration == duration && duration > 0) {
                    val = 1.0
                }
                cell.progress.progress = val
                if cell.imgPlay.isHidden {
                    cell.indicator.startAnimating()
                } else {
                    cell.indicator.stopAnimating()
                }
            }
        }
    }
    
    private func setPlayer(url: URL) {
        asset = AVAsset(url: url)
        asset?.loadValuesAsynchronously(forKeys: ["playable"]) {[weak self] () in
            var error: NSError? = nil
            let status = self?.asset?.statusOfValue(forKey: "playable", error: &error)
            switch status {
            case .loaded:
                break
            case .failed:
                self?.asset = nil
                self?.setPlayer(url: url)
                return
            case .cancelled:
                break
            default:
                break
            }
        }
        if let asset = asset {
            playerItem = AVPlayerItem(asset: asset)
        }
        getDuration()
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = false

        player?.pause()
        isPlay = false
        if let player = player {
            loopVideo(videoPlayer: player)
        }
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        playerLayer?.videoGravity = .resizeAspect

        if let playerLayer = playerLayer {
            layer.addSublayer(playerLayer)
        }
        addPreodicTimer()
    }
    
    func getDuration() {
        durationObserver = playerItem?.observe(\.duration, changeHandler: { [weak self] (playerItem, _) in
            self?.duration = playerItem.duration.seconds
            let size = self?.asset?.videoSize()
            if (/(size?.width)*1.5) < /size?.height {
                self?.playerLayer?.videoGravity = .resizeAspectFill
            }
        })
    }
    
    func play() {
        isPlay = true
        player?.replaceCurrentItem(with: playerItem)
        player?.seek(to: .zero)
        DispatchQueue.main.async {
            self.isPlay = true
        }
    }
    
    func pause() {
        player?.seek(to: .zero)
        player?.pause()
        isPlay = false
        DispatchQueue.main.async {
            self.isPlay = false
        }
    }
    
    func loopVideo(videoPlayer: AVPlayer) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) {[weak self] notification in
            videoPlayer.seek(to: .zero)
            if /self?.isPlay {
                videoPlayer.play()
            }
        }
    }
    
    func stop() {
        isPlay = false
        player?.seek(to: .zero)
        player?.pause()
        asset?.cancelLoading()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        playerItem = nil
        asset = nil
        timer = nil
        durationObserver = nil
        removeFromSuperview()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.suspend()
        durationObserver?.invalidate()
        stop()
        printLog("relesed \(self)")
    }
    
    class func newPlayer(height: CGFloat, url: String, currentPlayer: Player?, identifire: WhichPlayer)->Player? {
        let vw = Player()
        vw.identifire = identifire
        vw.currentPlayer = currentPlayer
        vw.frame = CGRect(x: 0, y: 0, width: screenWidth, height: height)
        vw.strUrl = url
        printLog("occupy \(self)")
        return vw
    }

}
