import type { ProviderAdapter, ProviderMetadata } from '../types.ts';

export class ProviderOperationError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: unknown;

  constructor(status: number, code: string, message: string, details: unknown = undefined) {
    super(message);
    this.name = 'ProviderOperationError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function validateProvider(provider: ProviderAdapter): string {
  if (!provider || typeof provider !== 'object') {
    throw new TypeError('Provider adapter must be an object.');
  }
  const id = String(provider.id ?? '').trim().toLowerCase();
  if (!id) throw new TypeError('Provider adapter id must not be empty.');
  if (!/^[a-z0-9][a-z0-9_-]*$/.test(id)) {
    throw new TypeError(`Provider adapter id "${id}" contains unsupported characters.`);
  }
  return id;
}

export class ProviderRegistry {
  private readonly providers: Map<string, ProviderAdapter>;

  constructor(providers: ProviderAdapter[] = []) {
    this.providers = new Map<string, ProviderAdapter>();
    for (const provider of providers) this.register(provider);
  }

  register(provider: ProviderAdapter): ProviderAdapter {
    const id = validateProvider(provider);
    this.providers.set(id, provider);
    return provider;
  }

  get(id: unknown): ProviderAdapter | null {
    return this.providers.get(String(id ?? '').trim().toLowerCase()) ?? null;
  }

  require(id: unknown): ProviderAdapter {
    const provider = this.get(id);
    if (!provider) {
      throw new ProviderOperationError(
        400,
        'unsupported-provider',
        `Unsupported media provider "${String(id ?? '').trim()}".`,
      );
    }
    return provider;
  }

  requireConfigured(id: unknown): ProviderAdapter {
    const provider = this.require(id);
    if (!provider.isConfigured()) {
      throw new ProviderOperationError(
        503,
        'provider-not-configured',
        provider.configurationError ?? `${provider.displayName ?? provider.id} is not configured.`,
      );
    }
    return provider;
  }

  list(): ProviderAdapter[] {
    return [...this.providers.values()];
  }

  ids(): string[] {
    return [...this.providers.keys()];
  }

  metadata(): ProviderMetadata[] {
    return this.list().map((provider) => ({
      id: provider.id,
      displayName: provider.displayName ?? provider.id,
      label: provider.label ?? provider.displayName ?? provider.id,
      description: provider.description ?? '',
      themeKey: provider.themeKey ?? provider.id,
      enabled: provider.enabled !== false,
      configured: provider.isConfigured(),
      ...(typeof provider.metadata === 'function' ? provider.metadata() : {}),
    }));
  }

  metadataById(): Record<string, ProviderMetadata> {
    return Object.fromEntries(this.metadata().map((item) => [item.id, item]));
  }
}
