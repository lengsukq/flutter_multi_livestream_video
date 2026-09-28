/// <reference path="../types/vendor.d.ts" />

import crypto from 'node:crypto';
import agoraToken from 'agora-token';
import type {
  ChatProviderAdapter,
  ChatProviderTokenResponse,
  MediaRole,
  ProviderFactoryContext,
  RoomAttendee,
  RoomEntry,
} from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';

const { ChatTokenBuilder } = agoraToken;
const DEFAULT_TOKEN_TTL_SECONDS = 3600;

export interface AgoraChatApi {
  createRoom(name: string): Promise<string>;
  ensureUser(username: string): Promise<string>;
  deleteRoom(roomId: string): Promise<void>;
  buildUserToken(userUuid: string, ttlSeconds: number): string;
}

export function agoraChatProviderUserId(userId: string): string {
  const digest = crypto.createHash('sha256').update(userId).digest('hex');
  return `u_${digest.slice(0, 40)}`;
}

export function normalizeAgoraChatTokenTtl(raw: unknown): number {
  const value = Number(raw);
  if (!Number.isFinite(value)) return DEFAULT_TOKEN_TTL_SECONDS;
  return Math.max(60, Math.min(24 * 60 * 60, Math.floor(value)));
}

function requireIdentity(attendee: RoomAttendee) {
  const participantId = attendee.attendeeId.trim();
  const userId = attendee.userId?.trim() || participantId;
  const displayName =
    attendee.displayName?.trim() || attendee.externalUserId?.trim() || userId;
  const role: MediaRole = attendee.role ?? 'participant';
  if (!participantId || !userId) {
    throw new ProviderOperationError(
      400,
      'invalid-argument',
      'Agora Chat requires a stable participant identity.',
    );
  }
  return { participantId, userId, displayName, role };
}

function createRestApi({
  appId,
  appCertificate,
  restHost,
  ownerUser,
}: {
  appId: string;
  appCertificate: string;
  restHost: string;
  ownerUser: string;
}): AgoraChatApi {
  const appToken = () => ChatTokenBuilder.buildAppToken(
    appId,
    appCertificate,
    24 * 60 * 60,
  );

  async function request(
    path: string,
    init: { method?: string; body?: unknown } = {},
  ): Promise<Record<string, unknown>> {
    const url = new URL(
      `app-id/${encodeURIComponent(appId)}/${path}`,
      restHost.endsWith('/') ? restHost : `${restHost}/`,
    );
    const response = await fetch(url, {
      method: init.method ?? 'GET',
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${appToken()}`,
        ...(init.body === undefined ? {} : { 'Content-Type': 'application/json' }),
      },
      ...(init.body === undefined ? {} : { body: JSON.stringify(init.body) }),
    });
    const text = await response.text();
    let payload: Record<string, unknown> = {};
    try {
      payload = text ? JSON.parse(text) as Record<string, unknown> : {};
    } catch (_) {
      // Surface non-JSON responses in the HTTP error below.
    }
    if (!response.ok) {
      throw new ProviderOperationError(
        response.status,
        'provider-api-error',
        `Agora Chat REST request failed: ${String(payload.error_description ?? payload.error ?? response.statusText)}`,
        { path, response: payload },
      );
    }
    return payload;
  }

  function extractUserUuid(payload: Record<string, unknown>): string | null {
    const entities = payload.entities;
    if (!Array.isArray(entities)) return null;
    const first = entities[0];
    if (!first || typeof first !== 'object') return null;
    const uuid = (first as Record<string, unknown>).uuid?.toString().trim();
    return uuid || null;
  }

  return {
    async ensureUser(username) {
      try {
        const existing = await request(`users/${encodeURIComponent(username)}`);
        const uuid = extractUserUuid(existing);
        if (uuid) return uuid;
      } catch (error) {
        if (!(error instanceof ProviderOperationError) || error.status !== 404) {
          throw error;
        }
      }
      const created = await request('users', {
        method: 'POST',
        body: { username },
      });
      const uuid = extractUserUuid(created);
      if (!uuid) {
        // Registration can race with another request. Query once more before failing.
        const existing = await request(`users/${encodeURIComponent(username)}`);
        const existingUuid = extractUserUuid(existing);
        if (existingUuid) return existingUuid;
        throw new ProviderOperationError(
          502,
          'provider-api-error',
          'Agora Chat did not return a user UUID after registration.',
        );
      }
      return uuid;
    },
    async createRoom(name) {
      await this.ensureUser(ownerUser);
      const payload = await request('chatrooms', {
        method: 'POST',
        body: {
          name,
          description: name,
          maxusers: 5000,
          owner: ownerUser,
        },
      });
      const data = payload.data;
      const id =
        data && typeof data === 'object'
          ? (data as Record<string, unknown>).id?.toString().trim()
          : null;
      if (!id) {
        throw new ProviderOperationError(
          502,
          'provider-api-error',
          'Agora Chat did not return a chat room id.',
          payload,
        );
      }
      return id;
    },
    async deleteRoom(roomId) {
      await request(`chatrooms/${encodeURIComponent(roomId)}`, {
        method: 'DELETE',
      });
    },
    buildUserToken(userUuid, ttlSeconds) {
      return ChatTokenBuilder.buildUserToken(
        appId,
        appCertificate,
        userUuid,
        ttlSeconds,
      );
    },
  };
}

export function createAgoraChatProvider({
  env = process.env,
  contractVersion,
  api: injectedApi,
}: ProviderFactoryContext & { api?: AgoraChatApi }): ChatProviderAdapter {
  const appId = env.AGORA_CHAT_APP_ID?.trim() || env.AGORA_APP_ID?.trim() || null;
  const appCertificate =
    env.AGORA_CHAT_APP_CERTIFICATE?.trim() ||
    env.AGORA_APP_CERTIFICATE?.trim() ||
    null;
  const appKey = env.AGORA_CHAT_APP_KEY?.trim() || null;
  const restHost = env.AGORA_CHAT_REST_HOST?.trim() || null;
  const ownerUser = env.AGORA_CHAT_OWNER_USER?.trim() || 'realtime_owner';
  const ttlSeconds = normalizeAgoraChatTokenTtl(
    env.AGORA_CHAT_TOKEN_TTL_SECONDS,
  );
  const configured =
    injectedApi != null ||
    Boolean(appId && appCertificate && appKey && restHost);
  const api = injectedApi ??
    (configured && appId && appCertificate && restHost
      ? createRestApi({
          appId,
          appCertificate,
          restHost,
          ownerUser,
        })
      : null);

  return {
    id: 'agora-chat',
    displayName: 'Agora Chat',
    label: 'Agora Chat',
    description: 'Agora managed persistent chat rooms',
    themeKey: 'agora-chat',
    configurationError:
      'Agora Chat is not configured. Set AGORA_CHAT_APP_KEY, AGORA_CHAT_REST_HOST, and AGORA_CHAT_APP_ID/AGORA_CHAT_APP_CERTIFICATE (or reuse AGORA_APP_ID/AGORA_APP_CERTIFICATE).',
    capabilityMatrix: [
      { key: 'sendMessage', label: 'Send message', support: 'supported' },
      {
        key: 'deleteMessage',
        label: 'Delete message',
        support: 'unsupported',
        note: 'The current provider-neutral adapter does not expose Agora moderation operations.',
      },
      {
        key: 'disconnectUser',
        label: 'Remove user',
        support: 'unsupported',
        note: 'The current provider-neutral adapter does not expose Agora moderation operations.',
      },
      {
        key: 'history',
        label: 'Server history',
        support: 'conditional',
        note: 'Agora Chat supports server history, but ChatSession history pagination is not part of Core v1.',
      },
    ],
    isConfigured: () => api != null,
    metadata: () => ({ appKey, restHost, tokenTtlSeconds: ttlSeconds }),
    async createRoom(roomCode) {
      if (!api) {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'Agora Chat is not configured.',
        );
      }
      const roomId = await api.createRoom(`Realtime room ${roomCode}`);
      return { chatProvider: 'agora-chat', chatRoomArn: roomId };
    },
    async issueToken({ entry, attendee }): Promise<ChatProviderTokenResponse> {
      if (!api || entry.chatProvider !== 'agora-chat' || !entry.chatRoomArn || !appKey) {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'This room is not bound to a configured Agora Chat provider.',
        );
      }
      const identity = requireIdentity(attendee);
      const providerUserId = agoraChatProviderUserId(identity.userId);
      const userUuid = await api.ensureUser(providerUserId);
      const token = api.buildUserToken(userUuid, ttlSeconds);
      return {
        contractVersion,
        chatProvider: 'agora-chat',
        roomCode: entry.roomCode,
        participantId: identity.participantId,
        userId: identity.userId,
        displayName: identity.displayName,
        role: identity.role,
        chat: {
          appKey,
          chatRoomId: entry.chatRoomArn,
          providerUserId,
          token,
          capabilities: ['SEND_MESSAGE'],
          tokenExpirationTimeMs: Date.now() + ttlSeconds * 1000,
        },
      };
    },
    async closeRoom(entry: RoomEntry) {
      if (!api || entry.chatProvider !== 'agora-chat' || !entry.chatRoomArn) {
        return;
      }
      await api.deleteRoom(entry.chatRoomArn);
    },
  };
}
