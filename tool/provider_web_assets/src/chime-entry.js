import DefaultMeetingSession from 'amazon-chime-sdk-js/build/meetingsession/DefaultMeetingSession.js';
import MeetingSessionConfiguration from 'amazon-chime-sdk-js/build/meetingsession/MeetingSessionConfiguration.js';
import DefaultDeviceController from 'amazon-chime-sdk-js/build/devicecontroller/DefaultDeviceController.js';
import ConsoleLogger from 'amazon-chime-sdk-js/build/logger/ConsoleLogger.js';
import LogLevel from 'amazon-chime-sdk-js/build/logger/LogLevel.js';
import MeetingSessionStatusCode from 'amazon-chime-sdk-js/build/meetingsession/MeetingSessionStatusCode.js';

// The Chime SDK publishes CommonJS modules. esbuild's ESM/CJS interop wraps
// their default exports in `{ default: ... }` for this import path. Expose
// actual constructors/enums to the macOS WKWebView and browser bridge rather
// than those wrapper objects (`new ChimeSDK.ConsoleLogger` otherwise fails).
const unwrapDefault = (value) => value?.default ?? value;

globalThis.ChimeSDK = {
  DefaultMeetingSession: unwrapDefault(DefaultMeetingSession),
  MeetingSessionConfiguration: unwrapDefault(MeetingSessionConfiguration),
  DefaultDeviceController: unwrapDefault(DefaultDeviceController),
  ConsoleLogger: unwrapDefault(ConsoleLogger),
  LogLevel: unwrapDefault(LogLevel),
  MeetingSessionStatusCode: unwrapDefault(MeetingSessionStatusCode),
};
