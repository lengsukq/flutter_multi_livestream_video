import TencentCloudChat from '@tencentcloud/chat';
import TIMUploadPlugin from 'tim-upload-plugin';
import AC from 'agora-chat';
import './ivs-chat-entry.js';
import { createAgoraChatBridge } from './agora-chat-entry.js';

// Tencent's Flutter Web plugin binds to these browser globals. Keep the SDKs
// local to this bundle while leaving their vendor APIs unchanged.
globalThis.TencentCloudChat = TencentCloudChat;
globalThis.TIMUploadPlugin = TIMUploadPlugin;
globalThis.AgoraChatBridge = createAgoraChatBridge(AC, globalThis);
