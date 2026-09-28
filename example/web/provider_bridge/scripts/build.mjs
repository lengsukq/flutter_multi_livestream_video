import { cp, mkdir, rm } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(scriptDir, '..');
const nodeModules = join(rootDir, 'node_modules');
const distDir = join(rootDir, 'dist');
const vendorsDir = join(distDir, 'vendors');

await rm(distDir, { recursive: true, force: true });
await mkdir(vendorsDir, { recursive: true });

const vendorFiles = [
  ['agora-rtc-sdk-ng/AgoraRTC_N-production.js', 'agora-rtc-sdk.js'],
  ['trtc-sdk-v5/trtc.js', 'trtc.js'],
  [
    'amazon-ivs-web-broadcast/dist/amazon-ivs-web-broadcast.js',
    'amazon-ivs-web-broadcast.js',
  ],
];

for (const [source, target] of vendorFiles) {
  await cp(join(nodeModules, source), join(vendorsDir, target));
}

await cp(
  join(nodeModules, 'trtc-sdk-v5/assets'),
  join(vendorsDir, 'trtc-assets'),
  { recursive: true },
);

await build({
  absWorkingDir: rootDir,
  entryPoints: ['src/aliyun-entry.js'],
  outfile: join(vendorsDir, 'aliyun-rtc-sdk.js'),
  bundle: true,
  platform: 'browser',
  format: 'iife',
  target: ['es2020'],
  minify: true,
  legalComments: 'eof',
});

await build({
  absWorkingDir: rootDir,
  entryPoints: ['src/chime-entry.js'],
  outfile: join(vendorsDir, 'chime-sdk.js'),
  bundle: true,
  platform: 'browser',
  format: 'iife',
  target: ['es2020'],
  minify: true,
  legalComments: 'eof',
  plugins: [{
    name: 'chime-meeting-only-barrel',
    setup(builder) {
      const meetingTask = join(
        nodeModules,
        'amazon-chime-sdk-js/build/task/PromoteToPrimaryMeetingTask.js',
      );
      builder.onResolve({ filter: /^\.\.$/ }, (args) =>
        args.importer === meetingTask
          ? { path: join(rootDir, 'src/chime-index-shim.js') }
          : undefined,
      );
    },
  }],
});

await build({
  absWorkingDir: rootDir,
  entryPoints: ['src/ivs-chat-entry.js'],
  outfile: join(vendorsDir, 'amazon-ivs-chat-messaging.js'),
  bundle: true,
  platform: 'browser',
  format: 'iife',
  target: ['es2020'],
  minify: true,
  legalComments: 'eof',
});

await cp(join(rootDir, 'src/bridge.js'), join(distDir, 'media-provider-bridge.js'));

const licensesDir = join(distDir, 'licenses');
await mkdir(licensesDir, { recursive: true });
for (const packageName of [
  'agora-rtc-sdk-ng',
  'aliyun-rtc-sdk',
  'amazon-chime-sdk-js',
  'amazon-ivs-chat-messaging',
  'amazon-ivs-web-broadcast',
  'trtc-sdk-v5',
  'eventemitter3',
]) {
  const packageDir = join(nodeModules, packageName);
  for (const name of ['LICENSE', 'LICENSE.txt', 'NOTICE']) {
    try {
      await cp(join(packageDir, name), join(licensesDir, `${packageName}-${name}`));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
}
