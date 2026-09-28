import type {
  ProviderAdapter,
  ProviderCapability,
  ProviderMetadata,
  RoomMode,
} from '../types.ts';

export const AWS_VENDOR_ID = 'aws';
export const AWS_MEETING_ENGINE = 'chime';
export const AWS_LIVE_ENGINE = 'ivs';

export function awsEngineForRoomMode(roomMode: RoomMode): string {
  return roomMode === 'broadcast' ? AWS_LIVE_ENGINE : AWS_MEETING_ENGINE;
}

export function isAwsEngine(providerId: unknown): boolean {
  const id = String(providerId ?? '').trim().toLowerCase();
  return id === AWS_MEETING_ENGINE || id === AWS_LIVE_ENGINE;
}

export function publicVendorForEngine(providerId: unknown): string {
  const id = String(providerId ?? '').trim().toLowerCase();
  return isAwsEngine(id) ? AWS_VENDOR_ID : id;
}

export function awsVendorMetadata(
  chime: ProviderAdapter,
  ivs: ProviderAdapter,
): ProviderMetadata {
  const configured = chime.isConfigured() && ivs.isConfigured();
  const capabilities: ProviderCapability[] = [
    {
      key: 'meeting', label: 'Meeting',
      support: chime.isConfigured() ? 'supported' : 'conditional',
      note: 'AWS Meeting routes to Amazon Chime SDK.',
    },
    {
      key: 'broadcastHost', label: 'Live Host',
      support: ivs.isConfigured() ? 'supported' : 'conditional',
      note: 'AWS Live routes hosts/guests to Amazon IVS Real-Time publishers.',
    },
    {
      key: 'broadcastViewer', label: 'Live Viewer',
      support: ivs.isConfigured() ? 'supported' : 'conditional',
      note: 'AWS Live viewers subscribe through Amazon IVS Real-Time without publishing local media.',
    },
  ];
  return {
    id: AWS_VENDOR_ID,
    displayName: 'AWS', label: 'AWS',
    description: 'Meeting uses Amazon Chime SDK; Live uses Amazon IVS Real-Time.',
    themeKey: 'aws',
    enabled: chime.enabled !== false || ivs.enabled !== false,
    configured,
    capabilities,
    engines: { meeting: AWS_MEETING_ENGINE, broadcast: AWS_LIVE_ENGINE },
    engineStatus: { chime: chime.isConfigured(), ivs: ivs.isConfigured() },
  };
}
