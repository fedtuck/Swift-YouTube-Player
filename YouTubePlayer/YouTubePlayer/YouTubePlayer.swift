//
//  VideoPlayerView.swift
//  YouTubePlayer
//
//  Created by Giles Van Gruisen on 12/21/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

import UIKit

public enum YouTubePlayerState: String {
    case unstarted = "-1"
    case ended = "0"
    case playing = "1"
    case paused = "2"
    case buffering = "3"
    case queued = "4"
}

public enum YouTubePlayerEvents: String {
    case youTubeIframeAPIReady = "onYouTubeIframeAPIReady"
    case ready = "onReady"
    case stateChange = "onStateChange"
    case playbackQualityChange = "onPlaybackQualityChange"
}

public enum YouTubePlaybackQuality: String {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case hd720 = "hd720"
    case hd1080 = "hd1080"
    case highResolution = "highres"
}

public protocol YouTubePlayerDelegate {
    func playerReady(videoPlayer: YouTubePlayerView)
    func playerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
    func playerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality)
    func playerShouldLoadURL(videoPlayer: YouTubePlayerView, url: NSURL?)->Bool
}

// Make delegate methods optional by providing default implementations
public extension YouTubePlayerDelegate {
    
    func playerReady(videoPlayer: YouTubePlayerView) {}
    func playerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState) {}
    func playerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality) {}
    
}

private extension URL {
    func queryStringComponents() -> [String: Any] {
        
        var dict = [String: Any]()
        
        // Check for query string
        if let query = self.query {
            
            // Loop through pairings (separated by &)
            for pair in query.components(separatedBy: "&") {
                
                // Pull key, val from from pair parts (separated by =) and set dict[key] = value
                let components = pair.components(separatedBy: "=")
                dict[components[0]] = components[1]
            }
            
        }
        
        return dict
    }
}

public func videoIDFromYouTubeURL(videoURL: URL) -> String? {
    let pathComponents = videoURL.pathComponents
    if let host = videoURL.host, pathComponents.count > 1 && host.hasSuffix("youtu.be") {
        return pathComponents[1]
    }
    return videoURL.queryStringComponents()["v"] as? String
}

/** Embed and control YouTube videos */
public class YouTubePlayerView: UIView, UIWebViewDelegate {
    
    public typealias YouTubePlayerParameters = [String: Any]
    
    private var webView: UIWebView!
    
    /** The readiness of the player */
    private(set) public var ready = false
    
    /** The current state of the video player */
    private(set) public var playerState = YouTubePlayerState.unstarted
    
    /** The current playback quality of the video player */
    private(set) public var playbackQuality = YouTubePlaybackQuality.small
    
    /** Used to configure the player */
    public var playerVars = YouTubePlayerParameters()
    
    /** Used to respond to player events */
    public var delegate: YouTubePlayerDelegate?
    
    public var allowsInlineMediaPlayback: Bool {
        get {
            return webView.allowsInlineMediaPlayback
        }
        set {
            webView.allowsInlineMediaPlayback = newValue
        }
    }
    
    // MARK: Various methods for initialization
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        buildWebView(parameters: playerParameters())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildWebView(parameters: playerParameters())
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        // Remove web view in case it's within view hierarchy, reset frame, add as subview
        webView.removeFromSuperview()
        webView.frame = bounds
        addSubview(webView)
    }
    
    
    // MARK: Web view initialization
    
    private func buildWebView(parameters: [String: Any]) {
        webView = UIWebView()
        webView.allowsInlineMediaPlayback = true
        webView.mediaPlaybackRequiresUserAction = false
        webView.delegate = self
        webView.scrollView.isScrollEnabled = false
    }
    
    
    // MARK: Load player
    
    public func loadVideoURL(videoURL: URL) {
        if let videoID = videoIDFromYouTubeURL(videoURL: videoURL) {
            loadVideoID(videoID: videoID)
        }
    }
    
    public func loadVideoID(videoID: String) {
        var playerParams = playerParameters()
        playerParams["videoId"] = videoID
        
        loadWebViewWithParameters(parameters: playerParams)
    }
    
    public func loadPlaylistID(playlistID: String) {
        // No videoId necessary when listType = playlist, list = [playlist Id]
        playerVars["listType"] = "playlist"
        playerVars["list"] = playlistID
        
        loadWebViewWithParameters(parameters: playerParameters())
    }
    
    
    // MARK: Player controls
    
    public func play() {
        let _ = evaluatePlayerCommand(command: "playVideo()")
    }
    
    public func pause() {
        let _ = evaluatePlayerCommand(command: "pauseVideo()")
    }
    
    public func stop() {
        let _ = evaluatePlayerCommand(command: "stopVideo()")
    }
    
    public func clear() {
        let _ = evaluatePlayerCommand(command: "clearVideo()")
    }
    
    public func seekTo(seconds: Float, seekAhead: Bool) {
        let _ = evaluatePlayerCommand(command: "seekTo(\(seconds), \(seekAhead))")
    }
    
    public func getDuration() -> String? {
        return evaluatePlayerCommand(command: "getDuration()")
    }
    
    public func getCurrentTime() -> String? {
        return evaluatePlayerCommand(command: "getCurrentTime()")
    }
    
    // MARK: Playlist controls
    
    public func previousVideo() {
        let _ = evaluatePlayerCommand(command: "previousVideo()")
    }
    
    public func nextVideo() {
        let _ = evaluatePlayerCommand(command: "nextVideo()")
    }
    
    private func evaluatePlayerCommand(command: String) -> String? {
        let fullCommand = "player." + command + ";"
        return webView.stringByEvaluatingJavaScript(from: fullCommand)
    }
    
    
    // MARK: Player setup
    
    private func loadWebViewWithParameters(parameters: YouTubePlayerParameters) {
        
        // Get HTML from player file in bundle
        let rawHTMLString = htmlStringWithFilePath(path: playerHTMLPath())!
        
        // Get JSON serialized parameters string
        let jsonParameters = serializedJSON(object: parameters)!
        
        // Replace %@ in rawHTMLString with jsonParameters string
        let htmlString = rawHTMLString.replacingOccurrences(of: "%@", with: jsonParameters)
        
        // Load HTML in web view
        webView.loadHTMLString(htmlString, baseURL: URL(string: "http://www.youtube.com"))
    }
    
    private func playerHTMLPath() -> String {
        return Bundle(for: self.classForCoder).path(forResource: "YTPlayer", ofType: "html")!
    }
    
    private func htmlStringWithFilePath(path: String) -> String? {
        
        do {
            
            // Get HTML string from path
            let htmlString = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
            
            return htmlString as String
            
        } catch _ {
            
            // Error fetching HTML
            printLog(strings: "Lookup error: no HTML file found for path")
            
            return nil
        }
    }
    
    
    // MARK: Player parameters and defaults
    
    private func playerParameters() -> YouTubePlayerParameters {
        
        return [
            "height": "100%",
            "width": "100%",
            "events": playerCallbacks(),
            "playerVars": playerVars
        ]
    }
    
    private func playerCallbacks() -> YouTubePlayerParameters {
        return [
            "onReady": "onReady",
            "onStateChange": "onStateChange",
            "onPlaybackQualityChange": "onPlaybackQualityChange",
            "onError": "onPlayerError"
        ]
    }
    
    private func serializedJSON(object: Any) -> String? {
        
        do {
            // Serialize to JSON string
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: JSONSerialization.WritingOptions.prettyPrinted)
            
            // Succeeded
            return NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) as? String
            
        } catch let jsonError {
            
            // JSON serialization failed
            print(jsonError)
            printLog(strings: "Error parsing JSON")
            
            return nil
        }
    }
    
    
    // MARK: JS Event Handling
    
    private func handleJSEvent(eventURL: URL) {
        
        // Grab the last component of the queryString as string
        let data: String? = eventURL.queryStringComponents()["data"] as? String
        
        if let host = eventURL.host, let event = YouTubePlayerEvents(rawValue: host) {
            
            // Check event type and handle accordingly
            switch event {
            case .youTubeIframeAPIReady:
                ready = true
                break
                
            case .ready:
                delegate?.playerReady(videoPlayer: self)
                
                break
                
            case .stateChange:
                if let newState = YouTubePlayerState(rawValue: data!) {
                    playerState = newState
                    delegate?.playerStateChanged(videoPlayer: self, playerState: newState)
                }
                
                break
                
            case .playbackQualityChange:
                if let newQuality = YouTubePlaybackQuality(rawValue: data!) {
                    playbackQuality = newQuality
                    delegate?.playerQualityChanged(videoPlayer: self, playbackQuality: newQuality)
                }
                
                break
            }
        }
    }
    
    
    // MARK: UIWebViewDelegate
    
    
    public func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        let url = request.url
        
        // Check if ytplayer event and, if so, pass to handleJSEvent
        if let url = url, url.scheme == "ytplayer" { handleJSEvent(eventURL: url) }
        
        return delegate?.playerShouldLoadURL(videoPlayer: self, url: url as NSURL?) ?? true
    }
}

private func printLog(strings: CustomStringConvertible...) {
    let toPrint = ["[YouTubePlayer]"] + strings
    print(toPrint, separator: " ", terminator: "\n")
}
