import { ProviderOperationError } from '../providers/provider-registry.ts';
export type Point = { x: number; y: number };
export type Shape = { id: string; tool: string; color: number; width: number; points: Point[]; text: string };
export type AnnotationCanvas = { canvasId: string; sourceKey: string; participantId: string; shapes: Shape[]; embeddedInVideo?: boolean };
// Erasure history is transient and scoped to the authoritative canvas object.
// It is deliberately omitted from student snapshots and serialized shapes.
const erasedHistory = new WeakMap<AnnotationCanvas, Array<{ shape: Shape; index: number }>>();
export const fail = (message: string, code = 'invalid-argument', status = 400): never => {
  throw new ProviderOperationError(status, code, message);
};
export const text = (value: unknown, name: string, max = 1000): string => {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
    fail(`${name} must contain 1-${max} characters`);
  }
  return (value as string).trim();
};
export const integer = (value: unknown, min: number, max: number): number => {
  if (!Number.isSafeInteger(value) || (value as number) < min || (value as number) > max) {
    fail(`Expected an integer between ${min} and ${max}`);
  }
  return value as number;
};
const points = (raw: unknown, unbounded = false): Point[] => {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 100) fail('Expected 1-100 annotation points');
  return (raw as unknown[]).map(value => {
    const p = value as Partial<Point> | null;
    const min = unbounded ? -1000 : 0;
    const max = unbounded ? 1000 : 1;
    if (!p || typeof p.x !== 'number' || typeof p.y !== 'number' ||
        !Number.isFinite(p.x) || !Number.isFinite(p.y) || p.x < min || p.x > max || p.y < min || p.y > max) {
      fail(unbounded ? 'Whiteboard scene coordinates out of range' : 'Annotation coordinates must be normalized');
    }
    return { x: p!.x!, y: p!.y! };
  });
};
export function applyAnnotation(canvas: AnnotationCanvas, operation: string, data: Record<string, unknown>, unbounded = false): boolean {
      if (operation === 'clear') { canvas.shapes = []; erasedHistory.delete(canvas); return true; }
      if (operation === 'undo') {
        const history = erasedHistory.get(canvas);
        if (history?.length) {
          const erased = history.pop()!;
          canvas.shapes.splice(Math.min(erased.index, canvas.shapes.length), 0, erased.shape);
          return true;
        }
        if (!canvas.shapes.length) return false;
        canvas.shapes.pop(); return true;
      }
      const id = text(data.id, 'Shape id', 128);
      if (operation === 'erase') {
        const index = canvas.shapes.findIndex(s => s.id === id);
        if (index < 0) fail('Shape not found', 'invalid-state', 409);
        const history = erasedHistory.get(canvas) ?? [];
        history.push({ index, shape: canvas.shapes.splice(index, 1)[0]! });
        erasedHistory.set(canvas, history);
        return true;
      }
      const batch = points(data.points, unbounded);
      if (operation === 'begin') {
        erasedHistory.delete(canvas);
        if (canvas.shapes.some(shape => shape.id === id)) fail('Shape already exists', 'idempotency-conflict', 409);
        if (!['pen', 'highlight', 'circle', 'arrow', 'text'].includes(String(data.tool))) fail('Unknown annotation tool');
        if (canvas.shapes.length >= 200) fail('Clear the canvas before adding more marks', 'resource-limit', 429);
        const color = integer(data.color, 0, 0xffffffff);
        const width = integer(data.width, 1, 20);
        const label = data.tool === 'text' ? text(data.text, 'Label', 200) : '';
        canvas.shapes.push({ id, tool: String(data.tool), color, width, points: batch, text: label });
      } else {
        erasedHistory.delete(canvas);
        const shape = canvas.shapes.find(value => value.id === id);
        if (!shape || !['pen', 'highlight'].includes(shape.tool)) fail('Stroke not found', 'invalid-state', 409);
        if (shape!.points.length + batch.length > 2048) fail('Stroke point limit reached', 'resource-limit', 429);
        shape!.points.push(...batch);
      }

 return true;
}
