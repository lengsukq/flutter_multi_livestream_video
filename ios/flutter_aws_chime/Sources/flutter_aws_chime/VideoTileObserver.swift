//
//  VideoTileObserver.swift
//  flutter_aws_chime
//
//  Created by Conan on 2023/9/9.
//


import AmazonChimeSDK
import AmazonChimeSDKMedia
import Foundation

class MyVideoTileObserver: VideoTileObserver {
    var methodChannel: MethodChannelCoordinator
    
    init(withMethodChannel methodChannel: MethodChannelCoordinator) {
        self.methodChannel = methodChannel
    }
    
    func videoTileDidAdd(tileState: VideoTileState) {
        methodChannel.callFlutterMethod(method: .videoTileAdd, args: videoTileStateToDict(state: tileState))
    }
    
    func videoTileDidRemove(tileState: VideoTileState) {
        MeetingSession.shared.meetingSession?.audioVideo.unbindVideoView(tileId: tileState.tileId)
        methodChannel.callFlutterMethod(method: .videoTileRemove, args: videoTileStateToDict(state: tileState))
    }
    
    func videoTileDidPause(tileState: VideoTileState) {
        callVideoTileEvent("videoTilePaused", tileState: tileState)
    }

    func videoTileDidResume(tileState: VideoTileState) {
        callVideoTileEvent("videoTileResumed", tileState: tileState)
    }

    func videoTileSizeDidChange(tileState: VideoTileState) {
        callVideoTileEvent("videoTileSizeChanged", tileState: tileState)
    }

    private func callVideoTileEvent(_ type: String, tileState: VideoTileState) {
        methodChannel.callFlutterEvent(
            type,
            args: ["videoTile": videoTileStateToDict(state: tileState)]
        )
    }
    
    private func videoTileStateToDict(state: VideoTileState) -> [String: Any?] {
        return [
            "tileId": state.tileId,
            "attendeeId": state.attendeeId,
            "videoStreamContentWidth": state.videoStreamContentWidth,
            "videoStreamContentHeight": state.videoStreamContentHeight,
            "isLocalTile": state.isLocalTile,
            "isContent": state.isContent
        ]
    }
}
