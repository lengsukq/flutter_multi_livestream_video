import { readFileSync, writeFileSync } from 'node:fs';
import type { ProviderRegistry } from '../providers/provider-registry.ts';
import type { ChatProviderRegistry } from '../chat/chat-provider-registry.ts';
import { AWS_VENDOR_ID, isAwsEngine } from '../providers/aws.ts';

export interface ProviderSelectionDependencies {
  providerRegistry: ProviderRegistry;
  chatProviderRegistry: ChatProviderRegistry;
  initialProvider: string;
  initialChatProvider: string;
  statePath: string;
  isVercel: boolean;
}

/** Default provider selection affects new rooms only, never existing bindings. */
export function createProviderSelection({
  providerRegistry, chatProviderRegistry,
  initialProvider: INITIAL_PROVIDER,
  initialChatProvider: INITIAL_CHAT_PROVIDER,
  statePath: PROVIDER_STATE_PATH,
  isVercel: IS_VERCEL,
}: ProviderSelectionDependencies) {
function loadPersistedProvider(): string {
  // Vercel instances are ephemeral and may run concurrently. Deployment config
  // is the only reliable source for its default provider.
  if (IS_VERCEL) {
    if (INITIAL_PROVIDER === AWS_VENDOR_ID) return AWS_VENDOR_ID;
    const initial = providerRegistry.require(INITIAL_PROVIDER);
    return initial.isConfigured() ? initial.id : AWS_VENDOR_ID;
  }
  try {
    const parsed = JSON.parse(readFileSync(PROVIDER_STATE_PATH, 'utf8')) as {
      provider?: unknown;
    };
    if (parsed?.provider === AWS_VENDOR_ID) return AWS_VENDOR_ID;
    if (isAwsEngine(parsed?.provider)) return AWS_VENDOR_ID;
    const provider = providerRegistry.get(parsed?.provider);
    if (provider?.isConfigured()) return provider.id;
  } catch (_) {
    // Missing/corrupt runtime state falls back to MEDIA_DEFAULT_PROVIDER.
  }
  if (INITIAL_PROVIDER === AWS_VENDOR_ID || isAwsEngine(INITIAL_PROVIDER)) return AWS_VENDOR_ID;
  const initial = providerRegistry.require(INITIAL_PROVIDER);
  return initial.isConfigured() ? initial.id : AWS_VENDOR_ID;
}

function loadPersistedChatProvider(): string | null {
  const configuredDefault = INITIAL_CHAT_PROVIDER === 'none'
    ? null
    : chatProviderRegistry.get(INITIAL_CHAT_PROVIDER);
  if (IS_VERCEL) {
    return configuredDefault?.isConfigured() ? configuredDefault.id : null;
  }
  try {
    const parsed = JSON.parse(readFileSync(PROVIDER_STATE_PATH, 'utf8')) as {
      chatProvider?: unknown;
    };
    const hasPersistedSelection = Object.prototype.hasOwnProperty.call(
      parsed,
      'chatProvider',
    );
    if (!hasPersistedSelection) {
      return configuredDefault?.isConfigured() ? configuredDefault.id : null;
    }
    if (parsed.chatProvider == null || parsed.chatProvider === 'none') return null;
    const provider = chatProviderRegistry.get(parsed.chatProvider);
    if (provider?.isConfigured()) return provider.id;
  } catch (_) {
    // Missing/corrupt state falls back to CHAT_DEFAULT_PROVIDER.
  }
  return configuredDefault?.isConfigured() ? configuredDefault.id : null;
}

function persistActiveProviders(mediaProvider: string, chatProvider: string | null): void {
  if (IS_VERCEL) return;
  try {
    writeFileSync(
      PROVIDER_STATE_PATH,
      JSON.stringify(
        {
          provider: mediaProvider,
          chatProvider: chatProvider ?? 'none',
          updatedAt: new Date().toISOString(),
        },
        null,
        2,
      ) + '\n',
      'utf8',
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Unable to persist media provider selection: ${message}`);
  }
}

return { loadPersistedProvider, loadPersistedChatProvider, persistActiveProviders };
}
