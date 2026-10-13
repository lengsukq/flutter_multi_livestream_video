import { copyFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(scriptDir, '..');
const modelDir = join(rootDir, 'assets/video-effects/models');
const modelPath = join(modelDir, 'selfie_segmenter_landscape.tflite');
const bootstrapModelPath = resolve(
  rootDir,
  '../../assets/provider_web_runtime/vendors/sdk-video-effects/models/selfie_segmenter_landscape.tflite',
);
const modelUrl =
  'https://storage.googleapis.com/mediapipe-models/image_segmenter/' +
  'selfie_segmenter_landscape/float16/latest/' +
  'selfie_segmenter_landscape.tflite';

await mkdir(modelDir, { recursive: true });
try {
  const response = await fetch(modelUrl);
  if (!response.ok) {
    throw new Error(
      `HTTP ${response.status} ${response.statusText}`,
    );
  }
  await writeFile(modelPath, Buffer.from(await response.arrayBuffer()));
  console.log(`Synced ${modelPath} from MediaPipe upstream`);
} catch (error) {
  console.warn(
    `MediaPipe download failed; bootstrapping from the existing SDK asset: ${error}`,
  );
  await copyFile(bootstrapModelPath, modelPath);
  console.log(`Bootstrapped ${modelPath}`);
}
