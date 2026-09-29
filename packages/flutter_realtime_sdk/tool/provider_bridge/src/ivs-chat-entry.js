import {
  ChatRoom,
  DeleteMessageRequest,
  DisconnectUserRequest,
  SendMessageRequest,
} from 'amazon-ivs-chat-messaging';

const sessions = new Map();

function parsePayload(value) {
  return typeof value === 'string' ? JSON.parse(value) : value;
}

function emit(session, type, payload = {}) {
  const callback = globalThis.__flutterIvsChatOnEvent;
  if (typeof callback === 'function') {
    callback(session.id, type, JSON.stringify(payload));
  }
}

function chatToken(value) {
  return {
    token: value.token,
    tokenExpirationTime: new Date(value.tokenExpirationTimeMs),
    sessionExpirationTime: new Date(value.sessionExpirationTimeMs),
  };
}

function normalizeAttributes(value) {
  if (!value || typeof value !== 'object') return {};
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, String(item)]),
  );
}

function normalizeMessage(message) {
  return {
    id: String(message.id || ''),
    userId: String(message.sender?.userId || ''),
    displayName: String(
      message.sender?.attributes?.displayName || message.sender?.userId || '',
    ),
    message: String(message.content || ''),
    timestampMs: message.sendTime instanceof Date
      ? message.sendTime.getTime()
      : Number(message.sendTime || Date.now()),
    attributes: normalizeAttributes(message.sender?.attributes),
    type: 'message',
  };
}

function createSession(id, serializedInfo) {
  if (sessions.has(id)) throw new Error(`IVS Chat session ${id} already exists.`);
  const info = parsePayload(serializedInfo);
  const chat = info?.chat;
  if (!chat?.region || !chat?.token) {
    throw new Error('IVS Chat join information is missing region or token.');
  }

  let initialToken = {
    token: chat.token,
    tokenExpirationTimeMs: chat.tokenExpirationTimeMs,
    sessionExpirationTimeMs: chat.sessionExpirationTimeMs,
  };
  const session = {
    id,
    connectedOnce: false,
    room: new ChatRoom({
      regionOrUrl: chat.region,
      maxReconnectAttempts: 4,
      tokenProvider: async () => {
        if (initialToken) {
          const token = initialToken;
          initialToken = null;
          return chatToken(token);
        }
        const callback = globalThis.__flutterIvsChatRequestToken;
        if (typeof callback !== 'function') {
          throw new Error('IVS Chat token refresh callback is unavailable.');
        }
        return chatToken(parsePayload(await callback(id)));
      },
    }),
    listeners: [],
  };

  session.listeners.push(
    session.room.addListener('connecting', () => {
      emit(session, 'connecting', { reconnecting: session.connectedOnce });
    }),
    session.room.addListener('connect', () => {
      session.connectedOnce = true;
      emit(session, 'connected');
    }),
    session.room.addListener('disconnect', (reason) => {
      emit(session, 'disconnected', { reason });
    }),
    session.room.addListener('message', (message) => {
      emit(session, 'message', normalizeMessage(message));
    }),
    session.room.addListener('messageDelete', (event) => {
      emit(session, 'messageDeleted', { messageId: event.messageId });
    }),
    session.room.addListener('userDisconnect', (event) => {
      emit(session, 'userDisconnected', { userId: event.userId });
    }),
  );
  sessions.set(id, session);
  return session;
}

function requireSession(id) {
  const session = sessions.get(id);
  if (!session) throw new Error(`Unknown IVS Chat session ${id}.`);
  return session;
}

const bridge = {
  async create(id, serializedInfo) {
    createSession(id, serializedInfo);
  },

  async connect(id) {
    const session = requireSession(id);
    if (session.room.state === 'connected') return;
    let unsubscribeConnect;
    let unsubscribeDisconnect;
    const connected = new Promise((resolve, reject) => {
      unsubscribeConnect = session.room.addListener('connect', resolve);
      unsubscribeDisconnect = session.room.addListener('disconnect', (reason) => {
        if (!session.connectedOnce) {
          reject(new Error(`IVS Chat disconnected before connecting: ${reason}`));
        }
      });
      session.room.connect();
    });
    try {
      await connected;
    } finally {
      unsubscribeConnect?.();
      unsubscribeDisconnect?.();
    }
  },

  async command(id, command, serializedArguments) {
    const session = requireSession(id);
    const args = parsePayload(serializedArguments) || {};
    switch (command) {
      case 'sendMessage':
        await session.room.sendMessage(new SendMessageRequest(args.message));
        return;
      case 'deleteMessage':
        await session.room.deleteMessage(
          new DeleteMessageRequest(args.messageId, 'Deleted by moderator.'),
        );
        return;
      case 'disconnectUser':
        await session.room.disconnectUser(
          new DisconnectUserRequest(args.userId, 'Disconnected by moderator.'),
        );
        return;
      case 'disconnect':
        session.room.disconnect();
        return;
      default:
        throw new Error(`Unsupported IVS Chat operation ${command}.`);
    }
  },

  async dispose(id) {
    const session = sessions.get(id);
    if (!session) return;
    session.room.disconnect();
    for (const unsubscribe of session.listeners) unsubscribe();
    session.listeners.length = 0;
    sessions.delete(id);
  },
};

globalThis.IvsChatMessagingBridge = bridge;
