import crypto from 'node:crypto';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import { applyAnnotation } from './annotation-state.ts';
import type { AnnotationCanvas } from './annotation-state.ts';
type Page = { id: string; title: string; canvas: AnnotationCanvas };
export type Whiteboard = { revision: number; activePageId: string; pages: Page[] };
const page = (title: string): Page => {
  const id = crypto.randomUUID();
  return { id, title, canvas: { canvasId: crypto.randomUUID(), sourceKey: id, participantId: '', shapes: [] } };
};
export function createWhiteboard(): Whiteboard {
  const first = page('Page 1'); return { revision: 0, activePageId: first.id, pages: [first] };
}
const conflict = (message: string): never => { throw new ProviderOperationError(409, 'canvas-conflict', message); };
export function applyWhiteboard(board: Whiteboard, operation: string, data: Record<string, unknown>): boolean {
  if (data.expectedRevision !== board.revision) conflict('Whiteboard revision changed; refresh and retry');
  const current = board.pages.find(p => p.id === board.activePageId)!;
  switch (operation) {
    case 'page.add': {
      if (board.pages.length >= 20) conflict('Whiteboard page limit reached');
      if (typeof data.title !== 'string' || !data.title.trim() || data.title.trim().length > 120) {
        throw new ProviderOperationError(400, 'invalid-argument', 'Use a title of 1-120 characters');
      }
      const next = page(data.title.trim()); board.pages.push(next); board.activePageId = next.id; break;
    }
    case 'page.select':
    case 'page.delete': {
      const index = board.pages.findIndex(p => p.id === data.pageId);
      if (index < 0) conflict('Page no longer exists');
      if (operation === 'page.select') { board.activePageId = board.pages[index]!.id; board.pages[index]!.canvas.canvasId = crypto.randomUUID(); }
      else {
        if (board.pages.length === 1) conflict('Keep at least one page');
        board.pages.splice(index, 1);
        if (board.activePageId === data.pageId) {
          const selected = board.pages[Math.max(0, index - 1)]!;
          board.activePageId = selected.id; selected.canvas.canvasId = crypto.randomUUID();
        }
      }
      break;
    }
    case 'begin': case 'append': case 'undo': case 'clear':
      if (data.pageId !== board.activePageId || data.canvasId !== current.canvas.canvasId) conflict('Canvas or active page changed');
      if (!applyAnnotation(current.canvas, operation, data, true)) return false;
      break;
    default: throw new ProviderOperationError(400, 'invalid-argument', 'Unknown whiteboard action');
  }
  board.revision++; return true;
}
export function whiteboardSnapshot(board: Whiteboard, teacher: boolean) {
  const canvas = board.pages.find(p => p.id === board.activePageId)!.canvas;
  return { revision: board.revision, maxPages: 20, canEdit: teacher,
    pages: board.pages.map(({ id, title }) => ({ id, title })), activePageId: board.activePageId,
    canvas: { ...canvas, shapes: canvas.shapes.map(s => ({ ...s, points: s.points.map(p => ({ ...p })) })) } };
}
