import {
  ChatTokenCapability,
  CreateChatTokenCommand,
  CreateRoomCommand,
  DeleteRoomCommand,
  IvschatClient,
} from '@aws-sdk/client-ivschat';
import type { ChatTokenCapability as ChatTokenCapabilityType } from '@aws-sdk/client-ivschat';
import type {
  ChatProviderAdapter,
  ChatProviderTokenResponse,
  MediaRole,
  ProviderFactoryContext,
  RoomAttendee,
  RoomEntry,
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
}: ProviderFactoryContext & { api?: IvsChatApi }): ChatProviderAdapter {
  const region =
    env.IVS_CHAT_REGION?.trim() ||
    env.AWS_REGION?.trim() ||
    env.AWS_DEFAULT_REGION?.trim() ||
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
    configurationError:
      'Amazon IVS Chat is not configured. Set IVS_CHAT_REGION (or AWS_REGION) and provide AWS credentials through the server IAM credential chain.',
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
    async closeRoom(entry: RoomEntry) {
      if (!api || entry.chatProvider !== 'ivs-chat' || !entry.chatRoomArn) {
        return;
      }
      try {
        await api.deleteRoom(entry.chatRoomArn);
      } catch (error) {
        fail('DeleteRoom', error);
      }
    },
  };
}
