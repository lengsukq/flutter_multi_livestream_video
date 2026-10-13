import type { Express, RequestHandler, Response } from 'express';
import type { ChatApplicationDependencies } from '../services/chat/dependencies.ts';
import { applicationHandler } from './application-handler.ts';
import { postChatRoomsByCodeMembers } from '../services/chat/post-chat-rooms-by-code-members.ts';
import { postRoomsByCodeChatMembers } from '../services/chat/post-rooms-by-code-chat-members.ts';
import { postRoomsByCodeChatManageRemove } from '../services/chat/post-rooms-by-code-chat-manage-remove.ts';
import { postRoomsByCodeChatManageClose } from '../services/chat/post-rooms-by-code-chat-manage-close.ts';
import { postChatRoomsByCodeManageRemove } from '../services/chat/post-chat-rooms-by-code-manage-remove.ts';
import { postChatRoomsByCodeManageClose } from '../services/chat/post-chat-rooms-by-code-manage-close.ts';
import { deleteApiChatRoomsByCode } from '../services/chat/delete-api-chat-rooms-by-code.ts';
import { getApiChatCloudRooms } from '../services/chat/get-api-chat-cloud-rooms.ts';
import { deleteApiChatCloudRoomsByProviderByRoomid } from '../services/chat/delete-api-chat-cloud-rooms-by-provider-by-roomid.ts';
import { postChatRoomsByCodeCredentials } from '../services/chat/post-chat-rooms-by-code-credentials.ts';
import { getChatRooms } from '../services/chat/get-chat-rooms.ts';
import { postChatRooms } from '../services/chat/post-chat-rooms.ts';
import { postChatRoomsByCodeJoin } from '../services/chat/post-chat-rooms-by-code-join.ts';
export interface ChatRouteDependencies extends ChatApplicationDependencies {
  contractError(res: Response, status: number, code: string, message: string, details?: unknown): Response;
  sendProviderError(res: Response, error: unknown): Response | false;
  requireSameOrigin: RequestHandler;
  requireAdmin: RequestHandler;
}
export function registerChatRoutes(app: Express, dependencies: ChatRouteDependencies): void {
const { requireSameOrigin, requireAdmin } = dependencies;
app.post('/chat/rooms/:code/members', applicationHandler(postChatRoomsByCodeMembers, dependencies));
app.post('/rooms/:code/chat/members', applicationHandler(postRoomsByCodeChatMembers, dependencies));
app.post('/rooms/:code/chat/manage/remove', applicationHandler(postRoomsByCodeChatManageRemove, dependencies));
app.post('/rooms/:code/chat/manage/close', applicationHandler(postRoomsByCodeChatManageClose, dependencies));
app.post('/chat/rooms/:code/manage/remove', applicationHandler(postChatRoomsByCodeManageRemove, dependencies));
app.post('/chat/rooms/:code/manage/close', applicationHandler(postChatRoomsByCodeManageClose, dependencies));
app.delete('/api/chat/rooms/:code', requireSameOrigin, requireAdmin, applicationHandler(deleteApiChatRoomsByCode, dependencies));
app.get('/api/chat/cloud-rooms', requireAdmin, applicationHandler(getApiChatCloudRooms, dependencies));
app.delete('/api/chat/cloud-rooms/:provider/:roomId', requireSameOrigin,
  requireAdmin, applicationHandler(deleteApiChatCloudRoomsByProviderByRoomid, dependencies));
app.post('/chat/rooms/:code/credentials', applicationHandler(postChatRoomsByCodeCredentials, dependencies));
app.get('/chat/rooms', applicationHandler(getChatRooms, dependencies));
app.post('/chat/rooms', applicationHandler(postChatRooms, dependencies));
app.post('/chat/rooms/:code/join', applicationHandler(postChatRoomsByCodeJoin, dependencies));
}
