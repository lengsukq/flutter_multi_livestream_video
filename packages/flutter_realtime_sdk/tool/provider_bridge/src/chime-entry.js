import DefaultMeetingSession from 'amazon-chime-sdk-js/build/meetingsession/DefaultMeetingSession.js';
import MeetingSessionConfiguration from 'amazon-chime-sdk-js/build/meetingsession/MeetingSessionConfiguration.js';
import DefaultDeviceController from 'amazon-chime-sdk-js/build/devicecontroller/DefaultDeviceController.js';
import ConsoleLogger from 'amazon-chime-sdk-js/build/logger/ConsoleLogger.js';
import LogLevel from 'amazon-chime-sdk-js/build/logger/LogLevel.js';

globalThis.ChimeSDK = {
  DefaultMeetingSession,
  MeetingSessionConfiguration,
  DefaultDeviceController,
  ConsoleLogger,
  LogLevel,
};
