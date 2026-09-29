import {
  ChatTokenCapability,
  CreateChatTokenCommand,
  CreateRoomCommand,
  DeleteRoomCommand,
  DisconnectUserCommand,
  IvschatClient,
} from '@aws-sdk/client-ivschat';
import type { ChatTokenCapability as ChatTokenCapabilityType } from '@aws-sdk/client-ivschat';
import type {
  ChatProviderAdapter,
  ChatProviderTokenResponse,
  MediaRole,
  ProviderFactoryContext,
  RoomAttendee,
  ChatRoomEntry,
} from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';

export interface IvsChatToken {
  token: string;
  tokenExpirationTimeMs?: number;
  sessionExpirationTimeMs?: number;
  capabilities: ChatTokenCapabilityType[];
}

export interface IvsChatApi {
  createRoom(name: string): Promise<{ arn: string }>;
  createToken(input: {
    roomArn: string;
    userId: string;
    displayName: string;
    role: MediaRole;
    durationMinutes: number;
  }): Promise<IvsChatToken>;
  deleteRoom(roomArn: string): Promise<void>;
  disconnectUser?(roomArn: string, userId: string): Promise<void>;
}

export async function resolveIvsChatRegion(
  env: NodeJS.ProcessEnv = process.env,
): Promise<string | null> {
  const explicitRegion =
    env.IVS_CHAT_REGION?.trim() ||
    env.AWS_REGION?.trim() ||
    env.AWS_DEFAULT_REGION?.trim();
  if (explicitRegion) return explicitRegion;

  let client: IvschatClient | undefined;
  try {
    client = new IvschatClient({});
    return (await client.config.region()).trim() || null;
  } catch (_) {
    return null;
  } finally {
    client?.destroy();
  }
}

export function normalizeIvsChatTokenDurationMinutes(raw: unknown): number {
  const parsed = Number(raw ?? 60);
  if (!Number.isFinite(parsed)) return 60;
  return Math.max(1, Math.min(180, Math.trunc(parsed)));
}

export function ivsChatCapabilitiesForRole(
  role: MediaRole,
): ChatTokenCapabilityType[] {
  return role === 'host'
    ? [
        ChatTokenCapability.SEND_MESSAGE,
        ChatTokenCapability.DELETE_MESSAGE,
        ChatTokenCapability.DISCONNECT_USER,
      ]
    : [ChatTokenCapability.SEND_MESSAGE];
}

function createAwsApi(region: string): IvsChatApi {
  const client = new IvschatClient({ region });
  return {
    async createRoom(name) {
      const result = await client.send(
        new CreateRoomCommand({
          name,
          maximumMessageRatePerSecond: 10,
          maximumMessageLength: 500,
        }),
      );
      const arn = result.arn?.trim();
      if (!arn) throw new Error('IVS Chat CreateRoom returned no room ARN.');
      return { arn };
    },
    async createToken({
      roomArn,
      userId,
      displayName,
      role,
      durationMinutes,
    }) {
      const capabilities = ivsChatCapabilitiesForRole(role);
      const result = await client.send(
        new CreateChatTokenCommand({
          roomIdentifier: roomArn,
          userId,
          capabilities,
          sessionDurationInMinutes: durationMinutes,
          attributes: {
            displayName,
            role,
          },
        }),
      );
      const token = result.token?.trim();
      if (!token) {
        throw new Error('IVS Chat CreateChatToken returned no token.');
      }
      return {
        token,
        capabilities,
        tokenExpirationTimeMs: result.tokenExpirationTime?.getTime(),
        sessionExpirationTimeMs: result.sessionExpirationTime?.getTime(),
      };
    },
    async deleteRoom(roomArn) {
      await client.send(new DeleteRoomCommand({ identifier: roomArn }));
    },
    async disconnectUser(roomArn, userId) {
      await client.send(
        new DisconnectUserCommand({
          roomIdentifier: roomArn,
          userId,
          reason: 'Removed by room host',
        }),
      );
    },
  };
}

function fail(operation: string, error: unknown): never {
  if (error instanceof ProviderOperationError) throw error;
  throw new ProviderOperationError(
    502,
    'provider-api-error',
    `Amazon IVS Chat ${operation} failed.`,
    error instanceof Error
      ? { name: error.name, message: error.message }
      : String(error),
  );
}

function requireAttendeeIdentity(attendee: RoomAttendee): {
  participantId: string;
  userId: string;
  displayName: string;
  role: MediaRole;
} {
  const participantId = attendee.attendeeId.trim();
  const userId = attendee.userId?.trim() || participantId;
  const displayName =
    attendee.displayName?.trim() ||
    attendee.externalUserId?.trim() ||
    userId;
  const role = attendee.role ?? 'participant';
  if (!participantId || !userId) {
    throw new ProviderOperationError(
      400,
      'invalid-argument',
      'Chat token requires a stable participant identity.',
    );
  }
  return { participantId, userId, displayName, role };
}

export function createIvsChatProvider({
  env = process.env,
  contractVersion,
  api: injectedApi,
  resolvedRegion,
}: ProviderFactoryContext & {
  api?: IvsChatApi;
  resolvedRegion?: string | null;
}): ChatProviderAdapter {
  const region =
    env.IVS_CHAT_REGION?.trim() ||
    env.AWS_REGION?.trim() ||
    env.AWS_DEFAULT_REGION?.trim() ||
    resolvedRegion?.trim() ||
    null;
  const durationMinutes = normalizeIvsChatTokenDurationMinutes(
    env.IVS_CHAT_TOKEN_TTL_MINUTES,
  );
  const api = injectedApi ?? (region ? createAwsApi(region) : null);

  return {
    id: 'ivs-chat',
    displayName: 'Amazon IVS Chat',
    label: 'Amazon IVS Chat',
    description: 'AWS managed realtime chat',
    themeKey: 'ivs-chat',
    capabilityMatrix: [
      { key: 'sendMessage', label: 'Send message', support: 'supported' },
      {
        key: 'deleteMessage',
        label: 'Delete message',
        support: 'conditional',
        note: 'Available to host credentials with the IVS DELETE_MESSAGE capability.',
      },
      { key: 'memberList', label: 'Member list', support: 'conditional', note: 'Standalone demo rooms expose the authenticated logical member list to the host.' },
      { key: 'closeRoom', label: 'Close room', support: 'supported', note: 'Standalone host closes the provider room through the control plane.' },
      { key: 'muteMember', label: 'Mute member', support: 'unsupported', note: 'IVS Chat token capabilities do not provide provider-enforced per-member mute in this adapter.' },
      { key: 'banMember', label: 'Ban member', support: 'unsupported', note: 'Rejoin blocking is not implemented; disconnect and ban are intentionally distinct.' },
      { key: 'manageRoles', label: 'Manage roles', support: 'unsupported', note: 'Role changes require issuing new credentials and are not emulated.' },
      {
        key: 'disconnectUser',
        label: 'Remove user',
        support: 'conditional',
        note: 'Available to host credentials with the IVS DISCONNECT_USER capability.',
      },
      {
        key: 'history',
        label: 'Server history',
        support: 'unsupported',
        note: 'The current IVS Chat adapter keeps only session-local message state.',
      },
    ],
    configurationError:
      'Amazon IVS Chat is not configured. Set an AWS region through IVS_CHAT_REGION, AWS_REGION, AWS_DEFAULT_REGION, or the active AWS profile, and provide AWS credentials through the server IAM credential chain.',
    isConfigured: () => api != null,
    metadata: () => ({
      region,
      tokenDurationMinutes: durationMinutes,
      maximumMessageLength: 500,
    }),
    async createRoom(roomCode) {
      if (!api) {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'Amazon IVS Chat is not configured.',
        );
      }
      try {
        const room = await api.createRoom(`chat-${roomCode}`);
        return {
          chatProvider: 'ivs-chat',
          chatRoomArn: room.arn,
        };
      } catch (error) {
        fail('CreateRoom', error);
      }
    },
    async issueToken({ entry, attendee }): Promise<ChatProviderTokenResponse> {
      if (!api || !entry.chatRoomArn || entry.chatProvider !== 'ivs-chat') {
        throw new ProviderOperationError(
          503,
          'provider-not-configured',
          'This room is not bound to Amazon IVS Chat.',
        );
      }
      const identity = requireAttendeeIdentity(attendee);
      try {
        const issued = await api.createToken({
          roomArn: entry.chatRoomArn,
          userId: identity.userId,
          displayName: identity.displayName,
          role: identity.role,
          durationMinutes,
        });
        return {
          contractVersion,
          chatProvider: 'ivs-chat',
          roomCode: entry.roomCode,
          participantId: identity.participantId,
          userId: identity.userId,
          displayName: identity.displayName,
          role: identity.role,
          chat: {
            roomArn: entry.chatRoomArn,
            token: issued.token,
            capabilities: issued.capabilities,
            tokenExpirationTimeMs: issued.tokenExpirationTimeMs,
            sessionExpirationTimeMs: issued.sessionExpirationTimeMs,
            region,
          },
        };
      } catch (error) {
        fail('CreateChatToken', error);
      }
    },
    async closeRoom(entry: ChatRoomEntry) {
      if (!api || entry.chatProvider !== 'ivs-chat' || !entry.chatRoomArn) {
        return;
      }
      try {
        await api.deleteRoom(entry.chatRoomArn);
      } catch (error) {
        fail('DeleteRoom', error);
      }
    },
    async removeMember(entry, attendee) {
      if (
        !api ||
        !api.disconnectUser ||
        entry.chatProvider !== 'ivs-chat' ||
        !entry.chatRoomArn
      ) {
        throw new ProviderOperationError(
          400,
          'unsupported-feature',
          'Amazon IVS Chat member removal is not available.',
        );
      }
      const identity = requireAttendeeIdentity(attendee);
      try {
        await api.disconnectUser(entry.chatRoomArn, identity.userId);
      } catch (error) {
        fail('DisconnectUser', error);
      }
    },
  };
}
