import type {
  ProviderCapability,
  ProviderCapabilitySupport,
} from '../types.ts';

export type MediaCapabilityKey =
  | 'meeting'
  | 'broadcastHost'
  | 'broadcastViewer'
  | 'microphone'
  | 'camera'
  | 'screenShare'
  | 'rtcDataSend'
  | 'rtcDataReceive'
  | 'web'
  | 'credentialRefresh'
  | 'moderation'
  | 'closeRoom';

type CapabilityValue =
  | ProviderCapabilitySupport
  | {
      support: ProviderCapabilitySupport;
      note?: string;
    };

const definitions: Array<{ key: MediaCapabilityKey; label: string }> = [
  { key: 'meeting', label: '会议模式' },
  { key: 'broadcastHost', label: '直播主持' },
  { key: 'broadcastViewer', label: '直播观看' },
  { key: 'microphone', label: '麦克风发布' },
  { key: 'camera', label: '摄像头发布' },
  { key: 'screenShare', label: '屏幕共享' },
  { key: 'rtcDataSend', label: 'RTC Data 发送' },
  { key: 'rtcDataReceive', label: 'RTC Data 接收' },
  { key: 'web', label: 'Web 音视频' },
  { key: 'credentialRefresh', label: '凭证自动刷新' },
  { key: 'moderation', label: '主持人移除成员' },
  { key: 'closeRoom', label: '主持人关闭房间' },
];

export function mediaCapabilityMatrix(
  profile: Record<MediaCapabilityKey, CapabilityValue>,
): ProviderCapability[] {
  return definitions.map(({ key, label }) => {
    const value = profile[key];
    if (typeof value === 'string') {
      return { key, label, support: value };
    }
    return {
      key,
      label,
      support: value.support,
      ...(value.note ? { note: value.note } : {}),
    };
  });
}
