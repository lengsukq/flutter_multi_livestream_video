/// <reference path="../types/vendor.d.ts" />

import crypto from 'node:crypto';
import tlsSigApiV2 from 'tls-sig-api-v2';
import type {
  ChatProviderAdapter,
  ChatProviderCloudRoom,
  ChatProviderTokenResponse,
  MediaRole,
  ProviderFactoryContext,
  RoomAttendee,
  ChatRoomEntry,
} from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';

const { Api: TlsSigApi } = tlsSigApiV2;
const DEFAULT_REST_HOST = 'https://console.tim.qq.com';
const DEFAULT_TOKEN_TTL_SECONDS = 3600;

export interface TencentChatApi {
  createGroup(name: string): Promise<string>;
  listGroups(): Promise<ChatProviderCloudRoom[]>;
  importAccount(userId: string, displayName: string): Promise<void>;
  deleteGroup(groupId: string): Promise<void>;
  removeGroupMember?(groupId: string, userId: string): Promise<void>;
  buildUserSig(userId: string, ttlSeconds: number): string;
}

export function tencentChatProviderUserId(userId: string): string {
  const digest = crypto.createHash('sha256').update(userId).digest('hex');
  return `u_${digest.slice(0, 28)}`;
}

export function normalizeTencentChatTokenTtl(raw: unknown): number {
  const value = Number(raw);
  if (!Number.isFinite(value)) return DEFAULT_TOKEN_TTL_SECONDS;
  return Math.max(60, Math.min(7 * 24 * 60 * 60, Math.floor(value)));
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
      'Tencent Chat requires a stable participant identity.',
    );
  }
  return { participantId, userId, displayName, role };
}

function createRestApi({
  sdkAppId,
  secretKey,
  adminUser,
  restHost,
}: {
  sdkAppId: number;
  secretKey: string;
  adminUser: string;
  restHost: string;
}): TencentChatApi {
  const sigApi = new TlsSigApi(sdkAppId, secretKey);
  const adminSig = () => sigApi.genSig(adminUser, 24 * 60 * 60);

  async function request(path: string, body: Record<string, unknown>) {
    const url = new URL(path, restHost.endsWith('/') ? restHost : `${restHost}/`);
    url.searchParams.set('sdkappid', String(sdkAppId));
    url.searchParams.set('identifier', adminUser);
    url.searchParams.set('usersig', adminSig());
    url.searchParams.set('random', String(crypto.randomInt(100000, 999999999)));
    url.searchParams.set('contenttype', 'json');
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const text = await response.text();
    let payload: Record<string, unknown> = {};
    try {
      payload = text ? JSON.parse(text) as Record<string, unknown> : {};
    } catch (_) {
      // Surface the raw HTTP failure below.
    }
    const errorCode = Number(payload.ErrorCode ?? -1);
    if (!response.ok || errorCode !== 0) {
      throw new ProviderOperationError(
        response.ok ? 502 : response.status,
        'provider-api-error',
        `Tencent Chat REST request failed: ${String(payload.ErrorInfo ?? response.statusText)}`,
        { path, errorCode, response: payload },
      );
    }
    return payload;
  }

  return {
    async createGroup(name) {
      const payload = await request('v4/group_open_http_svc/create_group', {
        Type: 'Meeting',
        Name: name,
        ApplyJoinOption: 'FreeAccess',
      });
      const groupId = payload.GroupId?.toString().trim();
      if (!groupId) {
        throw new ProviderOperationError(
          502,
          'provider-api-error',
          'Tencent Chat did not return a group ID after creation.',
          payload,
        );
      }
      return groupId;
    },
    async listGroups() {
      const listPayload = await request(
        'v4/group_open_http_svc/get_appid_group_list',
        { Limit: 10000, Next: 0 },
      );
      const rawGroups = Array.isArray(listPayload.GroupIdList)
        ? listPayload.GroupIdList
        : [];
      const groupIds = rawGroups
        .map((item) => {
          if (!item || typeof item !== 'object') return '';
          return (item as Record<string, unknown>).GroupId?.toString().trim() ?? '';
        })
        .filter(Boolean);

      const rooms: ChatProviderCloudRoom[] = [];
      for (let index = 0; index < groupIds.length; index += 50) {
        const batch = groupIds.slice(index, index + 50);
        const infoPayload = await request('v4/group_open_http_svc/get_group_info', {
          GroupIdList: batch,
          ResponseFilter: {
            GroupBaseInfoFilter: [
              'Type',
              'Name',
              'CreateTime',
              'MemberNum',
            ],
          },
        });
        const infos = Array.isArray(infoPayload.GroupInfo)
          ? infoPayload.GroupInfo
          : [];
        for (const raw of infos) {
          if (!raw || typeof raw !== 'object') continue;
          const info = raw as Record<string, unknown>;
          const providerRoomId = info.GroupId?.toString().trim() ?? '';
          const name = info.Name?.toString().trim() ?? '';
          const legacy = providerRoomId.startsWith('rm_');
          const managedName = name.startsWith('Realtime room ');
          if (!providerRoomId || (!legacy && !managedName)) continue;
          const inferredRoomCode = managedName
            ? name.slice('Realtime room '.length).trim()
            : providerRoomId.slice(3).trim();
          const createTime = Number(info.CreateTime);
          const memberCount = Number(info.MemberNum);
          rooms.push({
            providerRoomId,
            name: name || providerRoomId,
            type: info.Type?.toString().trim() || undefined,
            memberCount: Number.isFinite(memberCount) ? memberCount : undefined,
            createdAt:
              Number.isFinite(createTime) && createTime > 0
                ? new Date(createTime * 1000).toISOString()
                : undefined,
            inferredRoomCode: inferredRoomCode || undefined,
          });
        }
      }
      return rooms;
    },
    async importAccount(userId, displayName) {
      await request('v4/im_open_login_svc/account_import', {
        UserID: userId,
        Nick: displayName.slice(0, 50),
      });
    },
    async deleteGroup(groupId) {
      await request('v4/group_open_http_svc/destroy_group', {
        GroupId: groupId,
      });
    },
    async removeGroupMember(groupId, userId) {
      await request('v4/group_open_http_svc/delete_group_member', {
        GroupId: groupId,
        MemberToDel_Account: [userId],
        Silence: 1,
      });
    },
    buildUserSig(userId, ttlSeconds) {
      return sigApi.genSig(userId, ttlSeconds);
    },
  };
}

export function createTencentChatProvider({
  env = process.env,
  contractVersion,
  api: injectedApi,
}: ProviderFactoryContext & { api?: TencentChatApi }): ChatProviderAdapter {
  const sdkAppId = Number(env.TENCENT_CHAT_SDK_APP_ID ?? 0);
  const secretKey = env.TENCENT_CHAT_SECRET_KEY?.trim() || null;
  const adminUser = env.TENCENT_CHAT_ADMIN_USER?.trim() || 'administrator';
  const restHost = env.TENCENT_CHAT_REST_HOST?.trim() || DEFAULT_REST_HOST;
  const ttlSeconds = normalizeTencentChatTokenTtl(
    env.TENCENT_CHAT_TOKEN_TTL_SECONDS,
  );
  const configured =
    injectedApi != null ||
    (Number.isSafeInteger(sdkAppId) && sdkAppId > 0 && Boolean(secretKey));
  const api = injectedApi ??
    (configured && secretKey
      ? createRestApi({ sdkAppId, secretKey, adminUser, restHost })
      : null);

  return {
    id: 'tencent-chat',
    displayName: 'Tencent Cloud Chat',
    label: 'Tencent Chat',
    description: 'Tencent Cloud managed persistent group chat',
    themeKey: 'tencent-chat',
    configurationError:
      'Tencent Chat is not configured. Set TENCENT_CHAT_SDK_APP_ID and TENCENT_CHAT_SECRET_KEY; TENCENT_CHAT_ADMIN_USER defaults to administrator.',
    capabilityMatrix: [
      { key: 'sendMessage', label: 'Send message', support: 'supported' },
      {
        key: 'deleteMessage',
        label: 'Delete message',
        support: 'unsupported',
        note: 'The current provider-neutral adapter does not expose Tencent moderation operations.',
      },
      { key: 'memberList', label: 'Member list', support: 'conditional', note: 'Standalone demo rooms expose the authenticated logical member list to the host.' },
      { key: 'closeRoom', label: 'Close room', support: 'supported', note: 'Standalone host closes the provider group through the control plane.' },
      { key: 'muteMember', label: 'Mute member', support: 'unsupported', note: 'Not exposed by the current provider-neutral Tencent adapter.' },
      { key: 'banMember', label: 'Ban member', support: 'unsupported', note: 'Not exposed by the current provider-neutral Tencent adapter.' },
      { key: 'manageRoles', label: 'Manage roles', support: 'unsupported', note: 'Not exposed by the current provider-neutral Tencent adapter.' },
      {
        key: 'disconnectUser',
        label: 'Remove user',
        support: 'conditional',
        note: 'Host control-plane management removes the provider account from the Tencent group.',
      },
      {
        key: 'history',
        label: 'Server history',
        support: 'conditional',
        note: 'Tencent Chat persists group messages, but ChatSession history pagination is not part of Core v1.',
      },
    ],
    isConfigured: () => api != null,
    metadata: () => ({ sdkAppId: sdkAppId || null, restHost, tokenTtlSeconds: ttlSeconds }),
    async createRoom(roomCode) {
      if (!api) {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'Tencent Chat is not configured.',
        );
      }
      // Let Tencent assign the provider group ID. The public room code is a
      // control-plane identifier and may be reused after this demo server is
      // restarted; binding it directly to GroupId leaves stale cloud groups
      // that make a later create fail with "group id has been used".
      const groupId = await api.createGroup(`Realtime room ${roomCode}`);
      return { chatProvider: 'tencent-chat', chatRoomArn: groupId };
    },
    async issueToken({ entry, attendee }): Promise<ChatProviderTokenResponse> {
      if (!api || entry.chatProvider !== 'tencent-chat' || !entry.chatRoomArn) {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'This room is not bound to Tencent Chat.',
        );
      }
      const identity = requireIdentity(attendee);
      const providerUserId = tencentChatProviderUserId(identity.userId);
      await api.importAccount(providerUserId, identity.displayName);
      const userSig = api.buildUserSig(providerUserId, ttlSeconds);
      return {
        contractVersion,
        chatProvider: 'tencent-chat',
        roomCode: entry.roomCode,
        participantId: identity.participantId,
        userId: identity.userId,
        displayName: identity.displayName,
        role: identity.role,
        chat: {
          sdkAppId,
          groupId: entry.chatRoomArn,
          providerUserId,
          userSig,
          capabilities: ['SEND_MESSAGE'],
          userSigExpirationTimeMs: Date.now() + ttlSeconds * 1000,
        },
      };
    },
    async closeRoom(entry: ChatRoomEntry) {
      if (!api || entry.chatProvider !== 'tencent-chat' || !entry.chatRoomArn) {
        return;
      }
      await api.deleteGroup(entry.chatRoomArn);
    },
    async removeMember(entry, attendee) {
      if (
        !api ||
        !api.removeGroupMember ||
        entry.chatProvider !== 'tencent-chat' ||
        !entry.chatRoomArn
      ) {
        throw new ProviderOperationError(
          400,
          'unsupported-feature',
          'Tencent Chat member removal is not available.',
        );
      }
      const identity = requireIdentity(attendee);
      await api.removeGroupMember(
        entry.chatRoomArn,
        tencentChatProviderUserId(identity.userId),
      );
    },
    async listCloudRooms() {
      if (!api) {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'Tencent Chat is not configured.',
        );
      }
      return api.listGroups();
    },
    async deleteCloudRoom(providerRoomId) {
      if (!api) {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'Tencent Chat is not configured.',
        );
      }
      await api.deleteGroup(providerRoomId);
    },
  };
}
