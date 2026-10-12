import { test } from "node:test";
import assert from "node:assert/strict";
import { RateLimiter, TtlCache } from "./limits";

test("cache entries expire", () => {
  const cache = new TtlCache<number>(1_000);
  cache.set("a", 1, 0);
  assert.equal(cache.get("a", 999), 1);
  assert.equal(cache.get("a", 1_000), undefined);
});

test("cache evicts the oldest entry when full", () => {
  const cache = new TtlCache<number>(1_000, 2);
  cache.set("a", 1, 0);
  cache.set("b", 2, 0);
  cache.set("c", 3, 0);
  assert.equal(cache.get("a", 0), undefined);
  assert.equal(cache.get("c", 0), 3);
});

test("rate limiter allows up to the limit per window", () => {
  const limiter = new RateLimiter(2, 1_000);
  assert.ok(limiter.allow("ip", 0));
  assert.ok(limiter.allow("ip", 10));
  assert.ok(!limiter.allow("ip", 20));
  assert.ok(limiter.allow("other", 20));
  assert.ok(limiter.allow("ip", 1_000));
});
