//
//  Player.swift
//  Mearging
//
//  Created by Charanbir sandhu on 07/07/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//https://developer.apple.com/documentation/avfoundation/avplayeritem/1386960-playbackbufferempty?language=objc

import UIKit
import AVKit

class RepeatingTimer {

    let timeInterval: TimeInterval
    
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now()+self.timeInterval, repeating: self.timeInterval)
        t.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return t
    }()

    var eventHandler: (() -> Void)?

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        resume()
        eventHandler = nil
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}


class Player: UIView {

    var task: URLSessionDataTask?
    var count = Int(0)
    var player: AVPlayer?
    var playerItem: AVItem?
    var playerLayer: AVPlayerLayer?
    
    var timer: RepeatingTimer?
    var setBufferTime = Double(0)
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
        if player == nil { return 0 }
        guard let timeRange = player?.currentItem?.loadedTimeRanges.first?.timeRangeValue else {
            return 0.0
        }
        let startSeconds = timeRange.start.seconds
        let durationSeconds = timeRange.duration.seconds
        return startSeconds + durationSeconds
    }
    
    func addPreodicTimer() {
        timer = RepeatingTimer(timeInterval: 0.05)
        timer?.eventHandler = {[weak self]()in
            DispatchQueue.main.sync {
                self?.refreshBuffered()
            }
        }
        timer?.resume()
    }
    
    private func refreshBuffered() {
        currentDuration = player?.currentTime().seconds ?? 0
        buffereSeconds = Double(availableDuration - currentDuration)
    }
    
    private func reInit() {
        if playerItem?.task?.state == .running {
            nilPlayer()
        }
    }
    
    func removeLoading() {
        if playerItem?.task?.state != .completed {
            nilPlayer()
        }
    }
    
    private func nilPlayer() {
        playerItem?.task?.cancel()
        playerItem?.session?.invalidateAndCancel()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        let url = strUrl
        strUrl = url
    }

    private func isPlayOrStop() {
//        print(buffereSeconds)

        if isPlay, ((availableDuration == duration && duration > 0) || buffereSeconds > setBufferTime) {
            if !(player?.isPlaying ?? false) {
                setBufferTime = 0
                player?.play()
            }
        } else {
            if player?.isPlaying ?? false {
                setBufferTime = 1
                player?.pause()
            }
        }
    }
    
    private func setPlayer(url: URL) {
        isPlay = false
        var oldData: Data? = nil
        do {
            if let urlFile = AVItem.getDirectoryPath() {
                oldData = try Data(contentsOf: urlFile)
            }
        } catch {
            print(error)
        }
        playerItem = AVItem(url: url, data: oldData)
        playerItem?.preferredPeakBitRate = 1000
        playerItem?.preferredForwardBufferDuration = 1
        getDuration()
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = false
        
        player?.pause()
        if let player = player {
            loopVideo(videoPlayer: player)
        }
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        playerLayer?.backgroundColor = UIColor.clear.cgColor
        playerLayer?.videoGravity = .resizeAspect
        
        if let playerLayer = playerLayer {
            layer.addSublayer(playerLayer)
        }
        addPreodicTimer()
    }
    
    func getDuration() {
        durationObserver?.invalidate()
        durationObserver = playerItem?.observe(\.duration, changeHandler: { [weak self] (playerItem, _) in
            self?.duration = playerItem.duration.seconds
        })
    }
    
    func play() {
        playerItem?.task?.resume()
        isPlay = true
        player?.seek(to: .zero)
        DispatchQueue.main.async {
            self.isPlay = true
        }
    }
    
    func pauseVideo() {
        player?.seek(to: .zero)
        player?.pause()
        isPlay = false
        DispatchQueue.main.async {
            self.isPlay = false
        }
    }
    
    func loopVideo(videoPlayer: AVPlayer) {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) {[weak self] notification in
            videoPlayer.seek(to: .zero)
            if self?.isPlay ?? false{
                videoPlayer.play()
            }
        }
    }
    
    func stop() {
        isPlay = false
        player?.seek(to: .zero)
        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        playerItem?.task = nil
        playerItem?.session = nil
        playerItem = nil
        timer = nil
        durationObserver = nil
        removeFromSuperview()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.suspend()
        playerItem?.task?.cancel()
        playerItem?.session?.invalidateAndCancel()
        durationObserver?.invalidate()
        stop()
    }
    
    class func newPlayer(height: CGFloat, url: String)->Player? {
        let vw = Player()
        vw.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height)
        vw.strUrl = url
        return vw
    }
    
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
