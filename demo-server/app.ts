// Multi-provider demo backend — provider credentials stay server-side.
//
// `npm start` is the single backend entry point. Flutter sends room/user intent;
// this server selects a provider for new rooms and preserves that binding for
// the room lifetime. Provider SDK/token details live under demo-server/providers.

import crypto from 'node:crypto';
import express, {
  type NextFunction,
  type Request,
  type Response,
} from 'express';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { createAgoraProvider } from './providers/agora.ts';
import { createArtcProvider } from './providers/artc.ts';
import { createChimeProvider } from './providers/chime.ts';
import { createLiveKitProvider } from './providers/livekit.ts';
import { createIvsProvider } from './providers/ivs.ts';
import {
  AWS_VENDOR_ID,
  awsEngineForRoomMode,
  awsVendorMetadata,
  isAwsEngine,
  publicVendorForEngine,
} from './providers/aws.ts';
import { ChatProviderRegistry } from './chat/chat-provider-registry.ts';
import { ChatRoomDirectory } from './chat/chat-room-directory.ts';
import { LiveInteractionDirectory } from './live/live-interactions.ts';
import { registerInteractionRoutes } from './routes/interaction-routes.ts';
import { registerRoomRoutes } from './routes/room-routes.ts';
import { registerChatRoutes } from './routes/chat-routes.ts';
import { registerLegacyChimeRoutes } from './routes/legacy-chime-routes.ts';
import { registerDashboardRoutes, type DashboardSelectionState } from './routes/dashboard-routes.ts';
import { requireRoomManager } from './room-access.ts';
import { RoomOperationQueue } from './classroom/room-operation-queue.ts';
import { ClassroomStateDirectory } from './classroom/classroom-state.ts';
import { FileClassroomStore } from './classroom/classroom-store.ts';
import {
  createIvsChatProvider,
  resolveIvsChatRegion,
} from './chat/ivs-chat.ts';
import { createTencentChatProvider } from './chat/tencent-chat.ts';
import { createAgoraChatProvider } from './chat/agora-chat.ts';
import {
  issueParticipantCredential,
  requireParticipantCredential,
} from './participant-credential.ts';
import {
  issueRoomOwnerCredential,
  matchesRoomOwnerCredential,
} from './room-owner-credential.ts';
import { ProviderOperationError, ProviderRegistry } from './providers/provider-registry.ts';
import { RoomDirectory } from './providers/room-directory.ts';
import { createRoomClosure } from './services/room-closure.ts';
import { createRoomRegistryService } from './services/room-registry-service.ts';
import { createAdminAuth } from './services/admin-auth.ts';
import { createProviderSelection } from './services/provider-selection.ts';
import { createRoomOperations } from './services/room-operations.ts';
import { normalizeRoomCode, normalizeUserId, normalizeDisplayName, normalizeDeviceId, bindDevicePresence, parseRole, parseRoomMode, creatorRoleForMode, joinRoleForRoom } from './services/room-input.ts';
import { createTrtcProvider } from './providers/trtc.ts';
import { localizeDemoMessage, resolveDemoLanguage } from './i18n.ts';
import type {
  ChatProviderAdapter,
  ChatRoomEntry,
  ChimeRoomEntry,
  MediaRole,
  ProviderAdapter,
  RoomAttendee,
  RoomMode,
  RoomEntry,
  RoomSummary,
} from './types.ts';

const CONTROL_REGION = process.env.AWS_REGION ?? 'us-east-1';
const MEDIA_REGION = process.env.CHIME_MEDIA_REGION ?? 'ap-southeast-1';
const CONTRACT_VERSION = 1;
const MEDIA_CONTRACT_HEADER = 'X-Media-Backend-Contract';
const CHAT_CONTRACT_HEADER = 'X-Realtime-Chat-Contract';
const LEGACY_CHIME_CONTRACT_HEADER = 'X-Chime-Backend-Contract';
const DEMO_BEARER_TOKEN = process.env.DEMO_BEARER_TOKEN?.trim() || null;
const MEDIA_ADMIN_PASSWORD = process.env.MEDIA_ADMIN_PASSWORD?.trim() || '';
const ADMIN_SESSION_COOKIE = 'media_admin_session';
const ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60;
const IS_VERCEL = process.env.VERCEL === '1';
const MEDIA_CONNECTIONS_ENABLED = parseBoolean(
  process.env.MEDIA_CONNECTIONS_ENABLED,
  !IS_VERCEL,
);
const INITIAL_PROVIDER = String(process.env.MEDIA_DEFAULT_PROVIDER ?? 'aws').trim().toLowerCase();
const INITIAL_CHAT_PROVIDER = String(process.env.CHAT_DEFAULT_PROVIDER ?? 'none').trim().toLowerCase();
const STARTED_AT = Date.now();
const EMPTY_CLOSE_AFTER_MS = Number(process.env.EMPTY_CLOSE_AFTER_MS ?? 90_000);
const PARTICIPANT_STALE_AFTER_MS = Number(
  process.env.PARTICIPANT_STALE_AFTER_MS ?? Math.max(120_000, EMPTY_CLOSE_AFTER_MS),
);
const SWEEP_INTERVAL_MS = 30_000;
const roomOperations = new RoomOperationQueue();
const liveInteractionDirectory = new LiveInteractionDirectory();
const classroomStateDir = process.env.CLASSROOM_STATE_DIR?.trim();
const classroomDirectory = new ClassroomStateDirectory(
  classroomStateDir ? new FileClassroomStore(classroomStateDir) : undefined,
);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROVIDER_STATE_PATH = process.env.MEDIA_PROVIDER_STATE_PATH ?? path.join(__dirname, '.provider-state.json');

const app = express();
app.set('trust proxy', 1);
app.use(cors({
  origin: true,
  methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Authorization',
    'Accept-Language',
    'Content-Type',
    'X-Media-Backend-Contract',
    'X-Realtime-Chat-Contract',
    'X-Chime-Backend-Contract',
  ],
  exposedHeaders: [MEDIA_CONTRACT_HEADER, CHAT_CONTRACT_HEADER],
  maxAge: 600,
}));
app.use(express.json({ limit: '64kb' }));
app.use((req, res, next) => {
  res.vary('Accept-Language');
  res.locals.language = resolveDemoLanguage(req.get('Accept-Language'));
  next();
});

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value == null || value.trim() === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

function bindLogicalIdentity(
  entry: RoomEntry,
  participantId: string,
  userId: string,
  displayName: string,
  deviceId: string | null,
  role: MediaRole,
): void {
  const current = entry.attendees.find(
    (attendee) => attendee.attendeeId === participantId,
  );
  if (!current) return;
  current.userId = userId;
  current.displayName = displayName;
  current.externalUserId = displayName;
  current.role = role;
  current.lastHeartbeatMs = Date.now();
  if (deviceId) current.deviceId = deviceId;
  entry.attendees = entry.attendees.filter((attendee) => {
    if (attendee.attendeeId === participantId) return true;
    if (attendee.role === 'host') {
      if (role === 'host') return false;
      // A normal join must not evict the logical owner merely by reusing its
      // public user id. The same device may replace its stale logical entry
      // without gaining host authority.
      return !(deviceId && attendee.deviceId === deviceId);
    }
    return (
      attendee.userId !== userId &&
      (!deviceId || attendee.deviceId !== deviceId)
    );
  });
}


const { hasAdminSession, setAdminCookie, clearAdminCookie, requireSameOrigin, requireAdmin } =
  createAdminAuth({
    password: MEDIA_ADMIN_PASSWORD,
    cookieName: ADMIN_SESSION_COOKIE,
    sessionTtlSeconds: ADMIN_SESSION_TTL_SECONDS,
    isVercel: IS_VERCEL, nodeEnv: process.env.NODE_ENV,
    contractError,
  });

function requireConnectionsEnabled(_req: Request, res: Response, next: NextFunction): Response | void {
  if (MEDIA_CONNECTIONS_ENABLED) return next();
  return contractError(res, 503, 'service-paused', 'The media connection service is paused.');
}

function requireLegacyConnectionAccess(req: Request, res: Response, next: NextFunction): Response | void {
  // Keep administrator cleanup available while the public connection API is paused.
  if (req.method === 'DELETE' && /^\/[^/]+$/.test(req.path)) return next();
  if (!MEDIA_CONNECTIONS_ENABLED) {
    return contractError(res, 503, 'service-paused', 'The media connection service is paused.');
  }
  if (
    DEMO_BEARER_TOKEN &&
    req.get('Authorization') !== `Bearer ${DEMO_BEARER_TOKEN}` &&
    !hasAdminSession(req)
  ) {
    return contractError(res, 401, 'unauthorized', 'A valid demo bearer token is required.');
  }
  next();
}

const chimeProvider = createChimeProvider({
  env: process.env,
  contractVersion: CONTRACT_VERSION,
  normalizeUserId,
});

function chatManagementCapabilities(
  provider: ChatProviderAdapter,
  canManage: boolean,
) {
  if (!canManage) {
    return {
      listMembers: false,
      removeMember: false,
      closeRoom: false,
      muteMember: false,
      banMember: false,
      recallMessage: false,
      manageRoles: false,
    };
  }
  return {
    listMembers: true,
    removeMember: typeof provider.removeMember === 'function',
    closeRoom: true,
    muteMember: false,
    banMember: false,
    recallMessage: false,
    manageRoles: false,
  };
}

function mediaManagementCapabilities(provider: ProviderAdapter) {
  return {
    listParticipants: true,
    removeParticipant:
      typeof provider.moderateRemoveParticipant === 'function',
    closeRoom: true,
    muteParticipant: false,
    stopParticipantVideo: false,
    changeParticipantRole: false,
  };
}

const ivsProvider = createIvsProvider({
  env: process.env,
  contractVersion: CONTRACT_VERSION,
  normalizeDisplayName,
});

const providerRegistry = new ProviderRegistry([
  chimeProvider,
  createLiveKitProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createAgoraProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createTrtcProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createArtcProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  ivsProvider,
]);
const ivsChatRegion = await resolveIvsChatRegion(process.env);
const chatProviderRegistry = new ChatProviderRegistry([
  createIvsChatProvider({
    env: process.env,
    contractVersion: CONTRACT_VERSION,
    resolvedRegion: ivsChatRegion,
  }),
  createTencentChatProvider({
    env: process.env,
    contractVersion: CONTRACT_VERSION,
  }),
  createAgoraChatProvider({
    env: process.env,
    contractVersion: CONTRACT_VERSION,
  }),
]);
const roomDirectory = new RoomDirectory();
const chatRoomDirectory = new ChatRoomDirectory();

const {
  generateRoomCode, registerRoom, assertRole, resolveRoom, resolveChimeRoom,
} = createRoomRegistryService({ roomDirectory, providerRegistry, chimeProvider });

const closeRoomUnlocked = createRoomClosure({
  providerRegistry, chatProviderRegistry, roomDirectory,
  classroomDirectory, liveInteractionDirectory, logEvent,
});
const {
  pruneStaleAttendees, withRoomOperation, assertRoomOpen, closeRoom,
  summarizeRoom, isRoomPartiallyClosed,
} = createRoomOperations({
  roomDirectory, providerRegistry, roomOperations,
  participantStaleAfterMs: PARTICIPANT_STALE_AFTER_MS, closeRoomUnlocked,
});

registerChatRoutes(app, {
  chatRoomDirectory, chatProviderRegistry,
  currentChatProvider: () => activeChatProvider,
  contractVersion: CONTRACT_VERSION,
  resolveRoom, contractError, sendProviderError, chatManagementCapabilities,
  closeRoom, normalizeUserId, normalizeDisplayName, generateRoomCode, logEvent,
  requireSameOrigin, requireAdmin,
});


const events: Array<{ ts: string; type: string; message: string }> = [];

if (INITIAL_PROVIDER !== AWS_VENDOR_ID) providerRegistry.require(INITIAL_PROVIDER);

function engineProviderForSelection(providerId: string, roomMode: RoomMode): ProviderAdapter {
  const engineId = providerId === AWS_VENDOR_ID
    ? awsEngineForRoomMode(roomMode)
    : providerId;
  return providerRegistry.requireConfigured(engineId);
}

function publicProviderId(engineId: string): string {
  return publicVendorForEngine(engineId);
}

function exposeVendorResponse<T extends { provider: string; [key: string]: unknown }>(
  response: T,
): T {
  if (!isAwsEngine(response.provider)) return response;
  const engine = response.provider;
  return { ...response, provider: AWS_VENDOR_ID, vendor: AWS_VENDOR_ID, engine };
}

function providerMetadataForDashboard() {
  return [
    awsVendorMetadata(chimeProvider, ivsProvider),
    ...providerRegistry.metadata().filter((item) => !isAwsEngine(item.id)),
  ];
}

function logEvent(type: string, message: string): void {
  events.unshift({ ts: new Date().toISOString(), type, message });
  if (events.length > 200) events.pop();
  console.log(`[${type}] ${message}`);
}

function contractError(
  res: Response,
  status: number,
  code: string,
  message: string,
  details: unknown = undefined,
): Response {
  return res.status(status).json({
    contractVersion: CONTRACT_VERSION,
    error: {
      code,
      message: localizeDemoMessage(message, res.locals.language ?? 'en'),
      ...(details === undefined ? {} : { details }),
    },
  });
}

function sendProviderError(res: Response, error: unknown): Response | false {
  if (error instanceof ProviderOperationError) {
    return contractError(res, error.status, error.code, error.message, error.details);
  }
  return false;
}

function requireRoomContract(req: Request, res: Response, next: NextFunction): Response | void {
  res.set(MEDIA_CONTRACT_HEADER, String(CONTRACT_VERSION));
  res.set(CHAT_CONTRACT_HEADER, String(CONTRACT_VERSION));
  const requestedVersion =
    req.get(MEDIA_CONTRACT_HEADER) ??
    req.get(CHAT_CONTRACT_HEADER) ??
    req.get(LEGACY_CHIME_CONTRACT_HEADER);
  if (requestedVersion && requestedVersion !== String(CONTRACT_VERSION)) {
    return contractError(
      res,
      400,
      'unsupported-contract-version',
      `This demo server supports backend contract v${CONTRACT_VERSION}.`,
    );
  }
  if (
    DEMO_BEARER_TOKEN &&
    req.get('Authorization') !== `Bearer ${DEMO_BEARER_TOKEN}` &&
    !hasAdminSession(req)
  ) {
    return contractError(res, 401, 'unauthorized', 'A valid demo bearer token is required.');
  }
  next();
}

app.use('/rooms', (req, res, next) => {
  const isRoomList = req.method === 'GET' && req.path === '/';
  const isRoomDiscovery = req.method === 'GET' && req.path === '/discover';
  const isRoomCleanup = req.method === 'DELETE' && /^\/[^/]+$/.test(req.path);
  if (isRoomList || isRoomDiscovery || isRoomCleanup) {
    return requireRoomContract(req, res, next);
  }
  return requireConnectionsEnabled(req, res, () => requireRoomContract(req, res, next));
});
app.use(['/meetings', '/join'], requireLegacyConnectionAccess);

const { loadPersistedProvider, loadPersistedChatProvider, persistActiveProviders } =
  createProviderSelection({
    providerRegistry, chatProviderRegistry,
    initialProvider: INITIAL_PROVIDER,
    initialChatProvider: INITIAL_CHAT_PROVIDER,
    statePath: PROVIDER_STATE_PATH,
    isVercel: IS_VERCEL,
  });

let activeProvider = loadPersistedProvider();
let activeChatProvider = loadPersistedChatProvider();


if (!IS_VERCEL) {
  setInterval(() => {
    for (const entry of roomDirectory.entries()) {
      void withRoomOperation(entry, async () => {
        const now = Date.now();
        pruneStaleAttendees(entry, now, true);
        if (entry.roomMode === 'meeting') classroomDirectory.snapshot(entry, false);
        if (now - (entry.lastHeartbeatMs ?? 0) <= EMPTY_CLOSE_AFTER_MS) return;
        const idleSec = Math.round((now - entry.lastHeartbeatMs) / 1000);
        await closeRoomUnlocked(entry, `idle ${idleSec}s, no heartbeat`);
      }).catch((error) => console.error('auto-close failed', entry.roomCode, error));
    }
  }, SWEEP_INTERVAL_MS);
}

const dashboardSelection: DashboardSelectionState = {
  get activeProvider() { return activeProvider; },
  set activeProvider(value: string) { activeProvider = value; },
  get activeChatProvider() { return activeChatProvider; },
  set activeChatProvider(value: string | null) { activeChatProvider = value; },
};

registerDashboardRoutes(app, {
  state: dashboardSelection, providerRegistry, chatProviderRegistry,
  chatRoomDirectory, roomDirectory,
  dashboardFilePath: path.join(__dirname, 'public', 'index.html'),
  mediaConnectionsEnabled: MEDIA_CONNECTIONS_ENABLED,
  isVercel: IS_VERCEL, contractVersion: CONTRACT_VERSION,
  controlRegion: CONTROL_REGION, mediaRegion: MEDIA_REGION,
  startedAt: STARTED_AT,
  adminPassword: MEDIA_ADMIN_PASSWORD,
  adminSessionTtlSeconds: ADMIN_SESSION_TTL_SECONDS,
  currentConfigured: () => dashboardSelection.activeProvider === AWS_VENDOR_ID
    ? chimeProvider.isConfigured() || ivsProvider.isConfigured()
    : providerRegistry.require(dashboardSelection.activeProvider).isConfigured(),
  providerMetadataForDashboard, persistActiveProviders,
  setAdminCookie, clearAdminCookie, contractError,
  sendProviderError, logEvent, summarizeRoom, isRoomPartiallyClosed,
  events, requireSameOrigin, requireAdmin,
});

registerInteractionRoutes(app, {
  resolveRoom,
  withRoomOperation,
  assertRoomOpen,
  isRoomPartiallyClosed,
  pruneStaleAttendees,
  contractError,
  sendProviderError,
  classroomDirectory,
  liveInteractionDirectory,
  providerRegistry,
});

registerRoomRoutes(app, {
  roomDirectory, providerRegistry, chatProviderRegistry, chatRoomDirectory,
  classroomDirectory, currentProvider: () => activeProvider,
  currentChatProvider: () => activeChatProvider, contractVersion: CONTRACT_VERSION,
  resolveRoom, withRoomOperation, assertRoomOpen, isRoomPartiallyClosed,
  pruneStaleAttendees, bindLogicalIdentity, normalizeRoomCode, normalizeDeviceId,
  normalizeDisplayName, normalizeUserId, parseRole, parseRoomMode,
  creatorRoleForMode, joinRoleForRoom, generateRoomCode, engineProviderForSelection,
  publicProviderId, exposeVendorResponse, registerRoom, assertRole,
  closeRoom, closeRoomUnlocked, contractError, sendProviderError,
  mediaManagementCapabilities, chatManagementCapabilities, logEvent,
  requireSameOrigin, requireAdmin,
});

registerLegacyChimeRoutes(app, {
  chimeProvider, roomDirectory, classroomDirectory, liveInteractionDirectory,
  generateRoomCode, registerRoom, resolveChimeRoom, logEvent, withRoomOperation,
  requireSameOrigin, requireAdmin,
});

let server: ReturnType<typeof app.listen> | null = null;
if (!IS_VERCEL) {
  const port = Number(process.env.PORT ?? 3000);
  server = app.listen(port, '0.0.0.0', () => {
    const address = server?.address();
    const listeningPort = address && typeof address === 'object' ? address.port : port;
    console.log(`media-demo-server on :${listeningPort} (control=${CONTROL_REGION} media=${MEDIA_REGION})`);
    console.log(`active provider: ${activeProvider}`);
    for (const provider of providerRegistry.metadata()) {
      console.log(`${provider.displayName} configured: ${provider.configured ? 'yes' : 'no'}`);
    }
    console.log(`connections enabled: ${MEDIA_CONNECTIONS_ENABLED ? 'yes' : 'no'}`);
    console.log(`dashboard: http://127.0.0.1:${listeningPort}/`);
  });
}

export { app, server, providerRegistry, roomDirectory };
export default app;
