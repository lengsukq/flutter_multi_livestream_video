//
//  RealtimeObserver.swift
//  flutter_aws_chime
//
//  Created by Conan on 2023/9/9.
//
 
import AmazonChimeSDK
import AmazonChimeSDKMedia
import AVFoundation
import Flutter
import Foundation
import UIKit

class MyRealtimeObserver: RealtimeObserver {
    
    var methodChannel: MethodChannelCoordinator

    init(withMethodChannel methodChannel: MethodChannelCoordinator) {
        self.methodChannel = methodChannel
    }

    func volumeDidChange(volumeUpdates: [VolumeUpdate]) {
        for update in volumeUpdates {
            methodChannel.callFlutterEvent(
                "attendeeVolumeChanged",
                args: [
                    "attendeeId": update.attendeeInfo.attendeeId,
                    "externalUserId": update.attendeeInfo.externalUserId,
                    "volumeLevel": volumeLevelName(update.volumeLevel)
                ]
            )
        }
    }

    func signalStrengthDidChange(signalUpdates: [SignalUpdate]) {
        for update in signalUpdates {
            methodChannel.callFlutterEvent(
                "attendeeSignalStrengthChanged",
                args: [
                    "attendeeId": update.attendeeInfo.attendeeId,
                    "externalUserId": update.attendeeInfo.externalUserId,
                    "signalStrength": signalStrengthName(update.signalStrength)
                ]
            )
        }
    }

    func attendeesDidJoin(attendeeInfo: [AttendeeInfo]) {
        for currentAttendeeInfo in attendeeInfo {
            methodChannel.callFlutterMethod(method: .join, args: attendeeInfoToDictionary(attendeeInfo: currentAttendeeInfo))
        }
    }

    func attendeesDidLeave(attendeeInfo: [AttendeeInfo]) {
        for currentAttendeeInfo in attendeeInfo {
            methodChannel.callFlutterMethod(method: .leave, args: attendeeInfoToDictionary(attendeeInfo: currentAttendeeInfo))
        }
    }

    func attendeesDidDrop(attendeeInfo: [AttendeeInfo]) {
        for currentAttendeeInfo in attendeeInfo {
            methodChannel.callFlutterMethod(method: .drop, args: attendeeInfoToDictionary(attendeeInfo: currentAttendeeInfo))
        }
    }

    func attendeesDidMute(attendeeInfo: [AttendeeInfo]) {
        for currentAttendeeInfo in attendeeInfo {
            methodChannel.callFlutterMethod(method: .mute, args: attendeeInfoToDictionary(attendeeInfo: currentAttendeeInfo))
        }
    }

    func attendeesDidUnmute(attendeeInfo: [AttendeeInfo]) {
        for currentAttendeeInfo in attendeeInfo {
            methodChannel.callFlutterMethod(method: .unmute, args: attendeeInfoToDictionary(attendeeInfo: currentAttendeeInfo))
        }
    }

    private func attendeeInfoToDictionary(attendeeInfo: AttendeeInfo) -> [String: String] {
        return [
            "attendeeId": attendeeInfo.attendeeId,
            "externalUserId": attendeeInfo.externalUserId
        ]
    }

    private func volumeLevelName(_ level: VolumeLevel) -> String {
        switch level {
        case .muted: return "MUTED"
        case .notSpeaking: return "NOT_SPEAKING"
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        @unknown default: return "UNKNOWN"
        }
    }

    private func signalStrengthName(_ strength: SignalStrength) -> String {
        switch strength {
        case .none: return "NONE"
        case .low: return "LOW"
        case .high: return "HIGH"
        @unknown default: return "UNKNOWN"
        }
    }
    
    private func messageInfoToDictionary(dataMessage: AmazonChimeSDK.DataMessage) ->[String:Any] {
        return [
            "senderAttendeeId": dataMessage.senderAttendeeId,
            "senderExternalUserId": dataMessage.senderExternalUserId,
            "topic":dataMessage.topic,
            "timestampMs":dataMessage.timestampMs,
            "message": String(data: dataMessage.data, encoding: .utf8) ?? "",
            "throttled": dataMessage.throttled,
        ]
    }
}
