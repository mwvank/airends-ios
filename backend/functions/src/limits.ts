// Small in-memory helpers that keep costs down. They are per server instance,
// which is enough to absorb bursts; Google Cloud quotas and budget caps are the hard limits.

export class TtlCache<T> {
  private entries = new Map<string, { value: T; expires: number }>();

  constructor(private ttlMs: number, private maxEntries = 5_000) {}

  get(key: string, now = Date.now()): T | undefined {
    const entry = this.entries.get(key);
    if (!entry) return undefined;
    if (entry.expires <= now) {
      this.entries.delete(key);
      return undefined;
    }
    return entry.value;
  }

  set(key: string, value: T, now = Date.now()): void {
    if (this.entries.size >= this.maxEntries) {
      // Drop the oldest entry (Map keeps insertion order).
      const oldest = this.entries.keys().next().value;
      if (oldest !== undefined) this.entries.delete(oldest);
    }
    this.entries.set(key, { value, expires: now + this.ttlMs });
  }
}

export class RateLimiter {
  private windows = new Map<string, { start: number; count: number }>();

  constructor(private limit: number, private windowMs: number) {}

  allow(client: string, now = Date.now()): boolean {
    const window = this.windows.get(client);
    if (!window || now - window.start >= this.windowMs) {
      this.windows.set(client, { start: now, count: 1 });
      if (this.windows.size > 10_000) this.windows.clear();
      return true;
    }
    window.count += 1;
    return window.count <= this.limit;
  }
}
