package com.oneplusdream.flutter_aws_chime

import com.amazonaws.services.chime.sdk.meetings.audiovideo.AudioVideoObserver
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.RemoteVideoSource
import com.amazonaws.services.chime.sdk.meetings.session.MeetingSessionStatus

class AudioVideoObserver(val methodChannel: MethodChannelCoordinator) : AudioVideoObserver {
    override fun onAudioSessionCancelledReconnect() {
        methodChannel.callFlutterEvent("audioSessionReconnectCancelled")
    }

    override fun onAudioSessionDropped() {
        methodChannel.callFlutterEvent("audioSessionDropped")
    }

    override fun onAudioSessionStarted(reconnecting: Boolean) {
        methodChannel.callFlutterEvent(
                "audioSessionStarted",
                mapOf("reconnecting" to reconnecting)
        )
    }

    override fun onAudioSessionStartedConnecting(reconnecting: Boolean) {
        methodChannel.callFlutterEvent(
                "audioSessionConnecting",
                mapOf("reconnecting" to reconnecting)
        )
    }

    override fun onAudioSessionStopped(sessionStatus: MeetingSessionStatus) {
        MeetingSessionManager.onSessionStopped()
        methodChannel.callFlutterEvent(
                "audioSessionStopped",
                mapOf("statusCode" to sessionStatus.statusCode?.value?.toString())
        )
        methodChannel.callFlutterMethod(MethodCall.audioSessionDidStop, null)
    }

    override fun onCameraSendAvailabilityUpdated(available: Boolean) {
        methodChannel.callFlutterEvent(
                "cameraAvailabilityChanged",
                mapOf("available" to available)
        )
    }

    override fun onConnectionBecamePoor() {
        methodChannel.callFlutterEvent("connectionBecamePoor")
    }

    override fun onConnectionRecovered() {
        methodChannel.callFlutterEvent("connectionRecovered")
    }

    override fun onRemoteVideoSourceAvailable(sources: List<RemoteVideoSource>) {
        // Out of Scope
    }

    override fun onRemoteVideoSourceUnavailable(sources: List<RemoteVideoSource>) {
        // Out of Scope
    }

    override fun onVideoSessionStarted(sessionStatus: MeetingSessionStatus) {
        methodChannel.callFlutterEvent(
                "videoSessionStarted",
                mapOf("statusCode" to sessionStatus.statusCode?.value?.toString())
        )
    }

    override fun onVideoSessionStartedConnecting() {
        methodChannel.callFlutterEvent("videoSessionConnecting")
    }

    override fun onVideoSessionStopped(sessionStatus: MeetingSessionStatus) {
        methodChannel.callFlutterEvent(
                "videoSessionStopped",
                mapOf("statusCode" to sessionStatus.statusCode?.value?.toString())
        )
    }
}
