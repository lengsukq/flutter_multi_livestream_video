import AC from 'agora-chat';
import { createAgoraChatBridge } from './agora-chat-entry.js';
globalThis.AgoraChatBridge = createAgoraChatBridge(AC, globalThis);
