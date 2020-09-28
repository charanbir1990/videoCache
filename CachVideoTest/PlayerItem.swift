//
//  PlayerItemCustom.swift
//  Mearging
//
//  Created by Charanbir sandhu on 16/08/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//

import UIKit
import AVKit
var responce: URLResponse?

class AVItem: AVPlayerItem {
    fileprivate let url: URL
    var task: URLSessionDataTask?
    fileprivate let initialScheme: String?
    var session: URLSession?
    var mediaData: Data? = Data()
    var response: URLResponse?
    var pendingRequests = Set<AVAssetResourceLoadingRequest>()
    private let cachingPlayerItemScheme = "cachingPlayerItemScheme"
    private var isCache: Bool = false
    private var playingFromData = false

    convenience init(url: URL, data: Data?) {
        if let data = data {
            self.init(url: url, data: data, fileExtension: "mp4")
        } else {
            self.init(url: url, oldData: data)
        }
    }
    
    private init(url: URL, data: Data, fileExtension: String) {
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme,
            let urlWithCustomScheme = url.withScheme(cachingPlayerItemScheme) else {
                fatalError("Urls without a scheme are not supported")
        }
        self.url = url
        self.initialScheme = scheme
        
        mediaData = data
        playingFromData = true
        let asset = AVURLAsset(url: urlWithCustomScheme)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        response = responce
        processPendingRequests()
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        let configuration = URLSessionConfiguration.default
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        configuration.isDiscretionary = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        task = session?.dataTask(with: url)
    }
    
    private init(url: URL, oldData: Data?) {
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
        let configuration = URLSessionConfiguration.default
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        configuration.isDiscretionary = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        task = session?.dataTask(with: url)
    }
    
    func saveData() {
        guard let url = AVItem.getDirectoryPath(), let data = mediaData else {return}
        do {
            try data.write(to: url)
        } catch {
            print(error)
        }
    }

    class func getDirectoryPath() -> URL? {
        let fileManager = FileManager.default
        let path = (NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString).appendingPathComponent("VideoCache")
        let filePath = "file://\(path)"
        guard var url = URL(string: filePath) else {return nil}
        print(path)
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error)
            }
        }
        url.appendPathComponent("video.mp4")
        return url
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
        pendingRequests.insert(loadingRequest)
        print(loadingRequest.dataRequest?.requestedLength)
        processPendingRequests()
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        pendingRequests.remove(loadingRequest)
        print("didCancel")
    }
}

extension AVItem: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil {
            processPendingRequests()
        } else {
            print(error?.localizedDescription)
        }
        saveData()
    }
}

extension AVItem: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        mediaData?.append(data)
        processPendingRequests()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
        if !playingFromData {
            self.response = response
            responce = response
            processPendingRequests()
        }
    }
}

extension AVItem {
    
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
        contentInformationRequest?.isByteRangeAccessSupported = false
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
