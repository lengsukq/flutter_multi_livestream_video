import {Readable} from 'node:stream';
import {
  GetObjectCommand, HeadObjectCommand, DeleteObjectCommand, S3Client,
} from '@aws-sdk/client-s3';
import {RecordingProviderError} from './livekit-cloud-recording.ts';

/** Credentialed server-side read of files uploaded by a cloud recording vendor. */
export interface RecordingObjectReader {
  exists(bucket: string, key: string): Promise<boolean>;
  open(bucket: string, key: string): Promise<AsyncIterable<Uint8Array>>;
  remove?(bucket: string, key: string): Promise<void>;
}

export function s3RecordingReader(options: {
  region: string;
  accessKeyId?: string;
  secretAccessKey?: string;
  endpoint?: string;
}): RecordingObjectReader {
  const client = new S3Client({
    region: options.region,
    ...(options.accessKeyId && options.secretAccessKey
      ? {credentials: {
        accessKeyId: options.accessKeyId,
        secretAccessKey: options.secretAccessKey,
      }} : {}),
    ...(options.endpoint ? {endpoint: options.endpoint, forcePathStyle: true} : {}),
  });
  return {
    async exists(bucket, key) {
      try {
        const response = await client.send(new HeadObjectCommand({Bucket: bucket, Key: key}));
        return response.ContentLength == null || response.ContentLength > 0;
      } catch (error) {
        if (error && typeof error === 'object' &&
            ('name' in error) && ['NotFound', 'NoSuchKey'].includes(String(error.name))) {
          return false;
        }
        throw new RecordingProviderError('Cannot verify recorded MP4 in the configured S3 bucket.');
      }
    },
    async open(bucket, key) {
      let body;
      try {
        const result = await client.send(new GetObjectCommand({Bucket: bucket, Key: key}));
        body = result.Body;
      } catch {
        throw new RecordingProviderError('Cannot read completed MP4 from the configured S3 bucket.');
      }
      if (!body) throw new RecordingProviderError('The recording file is empty.');
      if (Symbol.asyncIterator in body) return body as AsyncIterable<Uint8Array>;
      return Readable.fromWeb(body.transformToWebStream() as never);
    },
    async remove(bucket, key) {
      await client.send(new DeleteObjectCommand({Bucket: bucket, Key: key}));
    },
  };
}
