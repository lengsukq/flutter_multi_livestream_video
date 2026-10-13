import { build } from 'esbuild';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdir, writeFile, cp } from 'node:fs/promises';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
for (const [slug, entry] of [['agora_chat', 'agora-chat-web-entry.js'], ['ivs_chat', 'ivs-chat-entry.js'], ['tencent_chat', 'tencent-chat-web-entry.js']]) {
  const assets = resolve(root, `../../packages/flutter_realtime_provider_${slug}/assets`);
  await mkdir(assets, { recursive: true });
  await build({ absWorkingDir: root, entryPoints: [`src/${entry}`], outfile: resolve(assets, `${slug.replaceAll('_', '-')}-provider.js`), bundle: true, platform: 'browser', format: 'iife', target: ['es2020'], minify: true, legalComments: 'eof' });
}
const trtcAssets = resolve(root, '../../packages/flutter_realtime_provider_trtc/assets');
await writeFile(resolve(trtcAssets, 'asset-path.js'), `globalThis.__realtimeTrtcAssetsPath = new URL('trtc-assets/', document.currentScript.src).toString();\n`);

const sdkAssets = resolve(root, 'dist');
const bridgeAssets = resolve(root, '../../packages/flutter_realtime_media_web/assets');
await mkdir(bridgeAssets, {recursive: true});
await cp(resolve(sdkAssets, 'media-provider-bridge.js'), resolve(bridgeAssets, 'media-provider-bridge.js'));
for (const [slug, files] of [['agora', ['agora-rtc-sdk.js']], ['trtc', ['trtc.js', 'trtc-assets']], ['artc', ['aliyun-rtc-sdk.js']], ['aws', ['chime-sdk.js', 'amazon-ivs-web-broadcast.js']]]) {
  const destination = resolve(root, `../../packages/flutter_realtime_provider_${slug}/assets`);
  await mkdir(destination, { recursive: true });
  for (const file of files) await cp(resolve(sdkAssets, 'vendors', file), resolve(destination, file), { recursive: true });
}
for (const slug of ['agora_chat', 'ivs_chat', 'tencent_chat']) {
  await cp(resolve(root, `../../packages/flutter_realtime_provider_${slug}/assets/${slug.replaceAll('_', '-')}-provider.js`), resolve(sdkAssets, `vendors/${slug.replaceAll('_', '-')}-provider.js`));
}
