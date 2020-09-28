//
//  Player.swift
//  Mearging
//
//  Created by Charanbir sandhu on 07/07/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//https://developer.apple.com/documentation/avfoundation/avplayeritem/1386960-playbackbufferempty?language=objc

import UIKit
import AVKit

class Player: UIView {
    var identifire: WhichPlayer = .current
    weak var currentPlayer: Player? {
        didSet {
            if currentPlayer == self {
                identifire = .current
            }
        }
    }
    var player: AVPlayer?
    var playerItem: AVItem?
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
                    printLog(url)
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
            playerItem?.task?.resume()
            printLog(buffereSeconds)
            break
        case .next:
            if currentPlayer != self, currentPlayer != nil {
                if (/currentPlayer?.availableDuration == /currentPlayer?.duration && /currentPlayer?.duration > 0) {
                    playerItem?.task?.resume()
                } else if /currentPlayer?.buffereSeconds > setBufferTime+5 {
                    playerItem?.task?.resume()
                }else if player?.currentItem != nil {
                    playerItem?.task?.suspend()
                }
            }
        case .previous:
            playerItem?.task?.suspend()
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
        playerItem = AVItem(url: url)
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
            guard let self = self else {return}
            self.duration = playerItem.duration.seconds
            let size = playerItem.asset.videoSize()
            if (/(size.width)*1.5) < /size.height {
                self.playerLayer?.videoGravity = .resizeAspectFill
            }
        })
    }
    
    func play() {
        isPlay = true
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
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        playerItem = nil
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

class AVItem: AVPlayerItem {
    
    fileprivate let url: URL
    var task: URLSessionDataTask?
    fileprivate let initialScheme: String?
    var session: URLSession?
    var mediaData: Data?
    var response: URLResponse?
    var pendingRequests = Set<AVAssetResourceLoadingRequest>()
    private let cachingPlayerItemScheme = "cachingPlayerItemScheme"
    
    convenience init(url: URL) {
        self.init(url: url, customFileExtension: nil)
    }
    
    init(url: URL, customFileExtension: String?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme,
            let urlWithCustomScheme = url.withScheme(cachingPlayerItemScheme) else {
                fatalError("Urls without a scheme are not supported")
        }
        
        self.url = url
        self.initialScheme = scheme

        let asset = AVURLAsset(url: urlWithCustomScheme)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
    }

    override init(asset: AVAsset, automaticallyLoadedAssetKeys: [String]?) {
        fatalError("not implemented")
    }
    
    deinit {
        session?.invalidateAndCancel()
    }
}

fileprivate extension URL {
    
    func withScheme(_ scheme: String) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = scheme
        return components?.url
    }
    
}
extension AVItem: AVAssetResourceLoaderDelegate {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if session == nil {
            let configuration = URLSessionConfiguration.default
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            task = session?.dataTask(with: url)
            task?.resume()
        }
        pendingRequests.insert(loadingRequest)
        processPendingRequests()
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        printLog("didCancel")
        pendingRequests.remove(loadingRequest)
    }
}

extension AVItem: URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        mediaData?.append(data)
        processPendingRequests()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
        mediaData = Data()
        self.response = response
        processPendingRequests()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil {
            processPendingRequests()
        } else {
            printLog(error)
        }
    }
    
    func processPendingRequests() {
            let requestsFulfilled = Set<AVAssetResourceLoadingRequest>(pendingRequests.compactMap {
                self.fillInContentInformationRequest($0.contentInformationRequest)
                if self.haveEnoughDataToFulfillRequest($0.dataRequest!) {
                    $0.finishLoading()
                    return $0
                }
                return nil
            })
            _ = requestsFulfilled.map { self.pendingRequests.remove($0) }
    }
    
    func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?) {
        guard let responseUnwrapped = response else {
            return
        }
        contentInformationRequest?.contentType = responseUnwrapped.mimeType
        contentInformationRequest?.contentLength = responseUnwrapped.expectedContentLength
        contentInformationRequest?.isByteRangeAccessSupported = true
    }
    
    func haveEnoughDataToFulfillRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        
        let requestedOffset = Int(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength
        let currentOffset = Int(dataRequest.currentOffset)
        
        guard let songDataUnwrapped = mediaData,
            songDataUnwrapped.count > currentOffset else {
            return false
        }
        
        let bytesToRespond = min(songDataUnwrapped.count - currentOffset, requestedLength)
        let dataToRespond = songDataUnwrapped.subdata(in: Range(uncheckedBounds: (currentOffset, currentOffset + bytesToRespond)))
        dataRequest.respond(with: dataToRespond)
        
        return songDataUnwrapped.count >= requestedLength + requestedOffset
    }
}
