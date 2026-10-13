// Single executable entrypoint; importing the app factory has no listener or timer.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createDemoApplication } from './app.ts';

const runtime = await createDemoApplication();
const { app, providerRegistry, roomDirectory } = runtime;
let server: ReturnType<typeof runtime.start> | null = null;
const isEntrypoint = process.argv[1] != null && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isEntrypoint && process.env.VERCEL !== '1') {
  server = runtime.start();
  const shutdown = () => { void runtime.stop().catch((error: unknown) => { console.error('shutdown failed', error); process.exitCode = 1; }); };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
}
export { app, server, providerRegistry, roomDirectory, createDemoApplication };
export default app;
