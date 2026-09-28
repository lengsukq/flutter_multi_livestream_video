import type {
  ChatProviderAdapter,
  ChatProviderMetadata,
} from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';

function validateProvider(provider: ChatProviderAdapter): string {
  if (!provider || typeof provider !== 'object') {
    throw new TypeError('Chat provider adapter must be an object.');
  }
  const id = String(provider.id ?? '').trim().toLowerCase();
  if (!id) throw new TypeError('Chat provider adapter id must not be empty.');
  if (!/^[a-z0-9][a-z0-9_-]*$/.test(id)) {
    throw new TypeError(
      `Chat provider adapter id "${id}" contains unsupported characters.`,
    );
  }
  return id;
}

export class ChatProviderRegistry {
  private readonly providers = new Map<string, ChatProviderAdapter>();

  constructor(providers: ChatProviderAdapter[] = []) {
    for (const provider of providers) this.register(provider);
  }

  register(provider: ChatProviderAdapter): ChatProviderAdapter {
    const id = validateProvider(provider);
    this.providers.set(id, provider);
    return provider;
  }

  get(id: unknown): ChatProviderAdapter | null {
    return this.providers.get(String(id ?? '').trim().toLowerCase()) ?? null;
  }

  require(id: unknown): ChatProviderAdapter {
    const provider = this.get(id);
    if (!provider) {
      throw new ProviderOperationError(
        400,
        'unsupported-provider',
        `Unsupported chat provider "${String(id ?? '').trim()}".`,
      );
    }
    return provider;
  }

  requireConfigured(id: unknown): ChatProviderAdapter {
    const provider = this.require(id);
    if (!provider.isConfigured()) {
      throw new ProviderOperationError(
        503,
        'provider-not-configured',
        provider.configurationError ??
          `${provider.displayName || provider.id} is not configured.`,
      );
    }
    return provider;
  }

  list(): ChatProviderAdapter[] {
    return [...this.providers.values()];
  }

  ids(): string[] {
    return [...this.providers.keys()];
  }

  metadata(): ChatProviderMetadata[] {
    return this.list().map((provider) => ({
      id: provider.id,
      displayName: provider.displayName || provider.id,
      label: provider.label || provider.displayName || provider.id,
      description: provider.description || '',
      themeKey: provider.themeKey || provider.id,
      enabled: provider.enabled !== false,
      configured: provider.isConfigured(),
      ...(typeof provider.metadata === 'function' ? provider.metadata() : {}),
    }));
  }
}
