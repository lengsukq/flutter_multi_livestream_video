import type { MediaRole, ProviderAdapter, RoomEntry } from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import type { ProviderRegistry } from '../providers/provider-registry.ts';
import type { RoomDirectory } from '../providers/room-directory.ts';

export interface RoomRegistryDependencies {
  roomDirectory: RoomDirectory;
  providerRegistry: ProviderRegistry;
  chimeProvider: ProviderAdapter;
}

/** Provider-neutral room code allocation, room lookup and alias registration. */
export function createRoomRegistryService({
  roomDirectory, providerRegistry, chimeProvider,
}: RoomRegistryDependencies) {
function generateRoomCode(): string {
  for (let i = 0; i < 50; i++) {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    if (!roomDirectory.has(code)) return code;
  }
  return String(Date.now()).slice(-6);
}

function providerAliases(provider: ProviderAdapter, entry: RoomEntry): string[] {
  return typeof provider.aliases === 'function' ? provider.aliases(entry) : [];
}

function registerRoom(provider: ProviderAdapter, entry: RoomEntry): RoomEntry {
  return roomDirectory.register(entry, providerAliases(provider, entry));
}

function assertRole(
  provider: ProviderAdapter,
  role: MediaRole,
  entry: RoomEntry | null = null,
): void {
  if (provider.supportsRole(role, entry)) return;
  const message = typeof provider.roleError === 'function'
    ? provider.roleError(entry, role)
    : `${provider.displayName ?? provider.id} does not support the ${role} role.`;
  throw new ProviderOperationError(400, 'unsupported-role', message);
}

async function resolveRoom(ref: unknown): Promise<RoomEntry | null> {
  const key = String(ref ?? '').trim();
  if (!key) return null;
  const local = roomDirectory.get(key);
  if (local) return local;

  for (const provider of providerRegistry.list()) {
    if (typeof provider.resolveExternalRoom !== 'function') continue;
    const entry = await provider.resolveExternalRoom(key, { allocateRoomCode: generateRoomCode });
    if (entry) return registerRoom(provider, entry);
  }
  return null;
}

async function resolveChimeRoom(ref: unknown): Promise<RoomEntry | null> {
  const local = roomDirectory.get(ref);
  if (local?.provider === 'chime') return local;
  const entry = await chimeProvider.resolveExternalRoom!(String(ref ?? '').trim(), {
    allocateRoomCode: generateRoomCode,
  });
  return entry ? registerRoom(chimeProvider, entry) : null;
}

return {
  generateRoomCode, registerRoom, assertRole, resolveRoom, resolveChimeRoom,
};
}
