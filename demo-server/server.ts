// Single public backend entrypoint. Runtime registration and provider-neutral
// route composition are isolated in app.ts; npm start and Vercel import this.
export { app, server, providerRegistry, roomDirectory } from './app.ts';
export { default } from './app.ts';
