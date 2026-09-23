//
//  AudioVideoObserver.swift
//  flutter_aws_chime
//
//  Created by Conan on 2023/9/9.
//

 
import AmazonChimeSDK
import AmazonChimeSDKMedia
import Foundation

class MyAudioVideoObserver: AudioVideoObserver {
    
    var methodChannel: MethodChannelCoordinator
    
    init(withMethodChannel methodChannel: MethodChannelCoordinator) {
        self.methodChannel = methodChannel
    }
    
    func audioSessionDidStartConnecting(reconnecting: Bool) {
        methodChannel.callFlutterEvent("audioSessionConnecting", args: ["reconnecting": reconnecting])
    }

    func audioSessionDidStart(reconnecting: Bool) {
        methodChannel.callFlutterEvent("audioSessionStarted", args: ["reconnecting": reconnecting])
    }

    func audioSessionDidDrop() {
        MeetingSession.shared.meetingSession?.logger.info(msg: "Meeting session dropped")
        methodChannel.callFlutterEvent("audioSessionDropped")
    }

    func audioSessionDidStopWithStatus(sessionStatus: MeetingSessionStatus) {
        methodChannel.stopAudioVideoFacadeObservers()
        MeetingSession.shared.meetingSession?.logger.info(msg: "Meeting session stopped with status \(sessionStatus.description)")
        methodChannel.callFlutterEvent("audioSessionStopped", args: ["statusCode": String(sessionStatus.statusCode.rawValue)])
        methodChannel.callFlutterMethod(method: .audioSessionDidStop, args: nil)
    }

    func audioSessionDidCancelReconnect() {
        methodChannel.callFlutterEvent("audioSessionReconnectCancelled")
    }
    
    func connectionDidRecover() {
        methodChannel.callFlutterEvent("connectionRecovered")
    }

    func connectionDidBecomePoor() {
        methodChannel.callFlutterEvent("connectionBecamePoor")
    }
    
    func videoSessionDidStartConnecting() {
        MeetingSession.shared.meetingSession?.logger.info(msg: "VideoSession started connecting...")
        methodChannel.callFlutterEvent("videoSessionConnecting")
    }
    
    func videoSessionDidStartWithStatus(sessionStatus: MeetingSessionStatus) {
        MeetingSession.shared.meetingSession?.logger.info(msg:
            "VideoSession started with status \(sessionStatus.statusCode.description)")
        methodChannel.callFlutterEvent("videoSessionStarted", args: ["statusCode": String(sessionStatus.statusCode.rawValue)])
    }

    func videoSessionDidStopWithStatus(sessionStatus: MeetingSessionStatus) {
        MeetingSession.shared.meetingSession?.logger.info(msg: "VideoSession stopped with status \(sessionStatus.statusCode.description)")
        methodChannel.callFlutterEvent("videoSessionStopped", args: ["statusCode": String(sessionStatus.statusCode.rawValue)])
    }

    func remoteVideoSourcesDidBecomeAvailable(sources: [RemoteVideoSource]) {
        for remoteSourceAvailable in sources {
            MeetingSession.shared.meetingSession?.logger.info(msg: "Remote video source became available: \(remoteSourceAvailable.attendeeId)")
        }
    }
    
    func remoteVideoSourcesDidBecomeUnavailable(sources: [RemoteVideoSource]) {
        for remoteSourcesUnavailable in sources {
            MeetingSession.shared.meetingSession?.logger.info(msg: "Remote video source became available: \(remoteSourcesUnavailable.attendeeId)")
        }
    }
    
    func cameraSendAvailabilityDidChange(available: Bool) {
        methodChannel.callFlutterEvent("cameraAvailabilityChanged", args: ["available": available])
    }
}
