import crypto from 'node:crypto';
import { applyAnnotation, fail, text, integer } from './annotation-state.ts';
import type { AnnotationCanvas } from './annotation-state.ts';
export type { Point, Shape, AnnotationCanvas } from './annotation-state.ts';
import { createWhiteboard, applyWhiteboard, whiteboardSnapshot } from './whiteboard-state.ts';
import type { Whiteboard } from './whiteboard-state.ts';
import type { RoomAttendee } from '../types.ts';

type Activity = {
  id: string; kind: 'quiz' | 'poll'; title: string; options: string[];
  correctOption?: number; closed: boolean; answers: Map<string, number>;
};
type Notice = { id: string; kind: 'announcement' | 'focus'; text: string; createdAt: string };
type Homework = { id: string; title: string; instructions: string; dueAt?: string };
type Material = { id: string; title: string; url: string };
export type ClassroomTools = {
  contentRevision: number;
  mode: 'members' | 'screen' | 'whiteboard'; whiteboard: Whiteboard;
  notices: Notice[]; homework: Homework[]; materials: Material[];
  timer: { title: string; endsAt: string } | null;
  activities: Activity[];
  annotation: AnnotationCanvas;
};
export const createClassroomTools = (): ClassroomTools => ({
  contentRevision: 0, mode: 'members', whiteboard: createWhiteboard(), notices: [], homework: [], materials: [], timer: null, activities: [],
  annotation: { canvasId: '', sourceKey: '', participantId: '', shapes: [] },
});
const boundedPush = <T>(items: T[], item: T): void => {
  items.push(item);
  if (items.length > 100) items.shift();
};

/** Authority lives here; IM/RTC frames carry invalidation hints only. New tools
 * intentionally remain transient even if legacy V1 persistence is configured. */
export function applyClassroomTool(
  tools: ClassroomTools, action: string, raw: Record<string, unknown>,
  requester: RoomAttendee, teacher: boolean,
): boolean {
  if (!teacher && action !== 'tool.activity.answer') fail('Teacher permission required', 'forbidden', 403);
  let data: Record<string, unknown>;
  try {
    const decoded: unknown = JSON.parse(String(raw.payload ?? '{}'));
    if (!decoded || typeof decoded !== 'object' || Array.isArray(decoded)) throw new Error();
    data = decoded as Record<string, unknown>;
  } catch { return fail('Invalid tool payload'); }
  if (action.startsWith('tool.whiteboard.')) {
    if (tools.mode !== 'whiteboard') fail('Whiteboard is not active', 'canvas-conflict', 409);
    return applyWhiteboard(tools.whiteboard, action.slice('tool.whiteboard.'.length), data);
  }
  switch (action) {
    case 'tool.content.mode': {
      if (data.expectedRevision !== tools.contentRevision) fail('Content revision changed; refresh and retry', 'content-conflict', 409);
      if (!['members', 'screen', 'whiteboard'].includes(String(data.mode))) fail('Unknown content mode');
      if (data.mode === 'screen') {
        const sourceKey = text(data.sourceKey, 'Screen source', 256);
        if (tools.annotation.sourceKey !== sourceKey || tools.annotation.participantId !== requester.attendeeId) {
          tools.contentRevision++;
      if (sourceKey) tools.mode = 'screen';
      else if (tools.mode === 'screen') tools.mode = 'members';
      tools.annotation = { canvasId: crypto.randomUUID(), sourceKey, participantId: requester.attendeeId, shapes: [] };
        }
      } else {
        tools.annotation = { canvasId: crypto.randomUUID(), sourceKey: '', participantId: '', shapes: [] };
      }
      if (data.mode === 'whiteboard' && tools.mode !== 'whiteboard') {
        const current = tools.whiteboard.pages.find(p => p.id === tools.whiteboard.activePageId)!;
        current.canvas.canvasId = crypto.randomUUID(); tools.whiteboard.revision++;
      }
      tools.contentRevision++;
      tools.mode = data.mode as ClassroomTools['mode'];
      break;
    }
    case 'tool.notice.publish': {
      if (data.kind !== 'announcement' && data.kind !== 'focus') fail('Unknown notice kind');
      boundedPush(tools.notices, { id: crypto.randomUUID(), kind: data.kind as Notice['kind'],
        text: text(data.text, 'Notice'), createdAt: new Date().toISOString() });
      break;
    }
    case 'tool.homework.publish': {
      const title = text(data.title, 'Title', 120);
      const instructions = text(data.instructions, 'Instructions', 2000);
      let dueAt: string | undefined;
      if (data.dueAt != null) {
        const ms = Date.parse(String(data.dueAt));
        if (!Number.isFinite(ms)) fail('Invalid due date');
        dueAt = new Date(ms).toISOString();
      }
      boundedPush(tools.homework, { id: crypto.randomUUID(), title, instructions, ...(dueAt ? { dueAt } : {}) });
      break;
    }
    case 'tool.material.share': {
      const title = text(data.title, 'Title', 120);
      const rawUrl = text(data.url, 'URL', 2048);
      let url: URL;
      try { url = new URL(rawUrl); } catch { return fail('Invalid material URL'); }
      if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) fail('Use an HTTP(S) material URL');
      boundedPush(tools.materials, { id: crypto.randomUUID(), title, url: url.toString() });
      break;
    }
    case 'tool.timer.start': {
      const seconds = integer(data.seconds, 1, 86400);
      tools.timer = { title: text(data.title, 'Title', 120), endsAt: new Date(Date.now() + seconds * 1000).toISOString() };
      break;
    }
    case 'tool.timer.stop': tools.timer = null; break;
    case 'tool.activity.publish': {
      if (data.kind !== 'quiz' && data.kind !== 'poll') fail('Unknown activity kind');
      if (!Array.isArray(data.options) || data.options.length < 2 || data.options.length > 8) fail('Use 2-8 options');
      const options = (data.options as unknown[]).map(value => text(value, 'Option', 200));
      if (new Set(options).size !== options.length) fail('Options must be distinct');
      const correctOption = data.kind === 'quiz' ? integer(data.correctOption, 0, options.length - 1) : undefined;
      // Do not evict open activities: an active question must remain answerable.
      if (tools.activities.length >= 100) fail('Activity limit reached', 'resource-limit', 429);
      tools.activities.push({ id: crypto.randomUUID(), kind: data.kind as Activity['kind'],
        title: text(data.title, 'Question', 500), options, correctOption, closed: false, answers: new Map() });
      break;
    }
    case 'tool.activity.answer':
    case 'tool.activity.close': {
      const activity = tools.activities.find(item => item.id === data.activityId);
      if (!activity) fail('Activity not found', 'activity-not-found', 404);
      if (action === 'tool.activity.close') {
        if (activity!.closed) return false;
        activity!.closed = true;
      } else {
        if (teacher) fail('Only students answer activities', 'forbidden', 403);
        if (activity!.closed) fail('Activity has ended', 'invalid-state', 409);
        const option = integer(data.option, 0, activity!.options.length - 1);
        const userId = requester.userId ?? requester.externalUserId;
        if (activity!.answers.get(userId) === option) return false;
        activity!.answers.set(userId, option);
      }
      break;
    }
    case 'tool.annotation.source': {
      const sourceKey = typeof data.sourceKey === 'string' ? data.sourceKey.trim() : '';
      if (sourceKey.length > 256) fail('Invalid screen source');
      if (tools.annotation.sourceKey === sourceKey &&
          (!sourceKey || tools.annotation.participantId === requester.attendeeId)) return false;
      tools.contentRevision++;
      if (sourceKey) tools.mode = 'screen';
      else if (tools.mode === 'screen') tools.mode = 'members';
      tools.annotation = { canvasId: crypto.randomUUID(), sourceKey,
        participantId: sourceKey ? requester.attendeeId : '', shapes: [] };
      break;
    }
    case 'tool.annotation.presentation': {
      const canvas = tools.annotation;
      if (!canvas.sourceKey || data.canvasId !== canvas.canvasId) fail('Shared screen changed', 'canvas-conflict', 409);
      if (typeof data.embeddedInVideo !== 'boolean') fail('Invalid annotation presentation');
      if (canvas.embeddedInVideo === data.embeddedInVideo) return false;
      canvas.embeddedInVideo = data.embeddedInVideo as boolean;
      break;
    }
    case 'tool.annotation.begin':
    case 'tool.annotation.append':
    case 'tool.annotation.erase':
    case 'tool.annotation.undo':
    case 'tool.annotation.clear': {
      const canvas = tools.annotation;
      if (!canvas.sourceKey || data.canvasId !== canvas.canvasId) fail('Shared screen changed', 'canvas-conflict', 409);
      return applyAnnotation(canvas, action.slice('tool.annotation.'.length), data);
      break;
    }
    default: return fail('Unknown classroom tool');
  }
  return true;
}

export function classroomToolsSnapshot(tools: ClassroomTools, teacher: boolean, userId: string) {
  return {
    content: { revision: tools.contentRevision, mode: tools.mode, canManage: teacher, screen: { ...tools.annotation, shapes: tools.annotation.shapes.map(shape => ({ ...shape, points: shape.points.map(p => ({ ...p })) })) }, whiteboard: whiteboardSnapshot(tools.whiteboard, teacher) },
    notices: tools.notices.map(value => ({ ...value })),
    homework: tools.homework.map(value => ({ ...value })),
    materials: tools.materials.map(value => ({ ...value })), timer: tools.timer ? { ...tools.timer } : null,
    annotation: { ...tools.annotation, shapes: tools.annotation.shapes.map(shape => ({ ...shape, points: shape.points.map(p => ({ ...p })) })) },
    activities: tools.activities.map(activity => {
      const counts = activity.options.map((_, index) => [...activity.answers.values()].filter(answer => answer === index).length);
      const reveal = teacher || activity.closed;
      return { id: activity.id, kind: activity.kind, title: activity.title, options: [...activity.options],
        closed: activity.closed, responseCount: activity.answers.size,
        selfAnswer: activity.answers.get(userId) ?? null,
        ...(reveal ? { counts } : {}),
        ...(reveal && activity.kind === 'quiz' ? { correctOption: activity.correctOption } : {}),
        ...(teacher ? { answers: Object.fromEntries(activity.answers) } : {}),
      };
    }),
  };
}
