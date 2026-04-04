/**
 * Tests for token authentication middleware
 */

import { describe, it, expect } from "vitest";
import { Hono } from "hono";
import { createTokenAuthMiddleware } from "./tokenAuth.ts";

// Helper to generate token with same algorithm as Open-ACE (async for Node.js compatibility)
async function generateToken(userId: number, port: number, randomPart: string, secret: string): Promise<string> {
  // SHA256({userId}:{port}:{randomPart}:{secret}).hexdigest()[:16]
  const dataToSign = `${userId}:${port}:${randomPart}:${secret}`;
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(dataToSign);
  const hashBuffer = await crypto.subtle.digest("SHA-256", dataBuffer);
  const hashArray = new Uint8Array(hashBuffer);
  const hexHash = Array.from(hashArray)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  const signature = hexHash.slice(0, 16);
  return `${userId}:${port}:${randomPart}:${signature}`;
}

describe("createTokenAuthMiddleware", () => {
  it("should skip validation when tokenSecret is not configured", async () => {
    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(undefined));
    app.get("/test", (c) => c.text("OK"));

    const res = await app.request("/test");
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("OK");
  });

  it("should skip validation when tokenSecret is empty", async () => {
    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(""));
    app.get("/test", (c) => c.text("OK"));

    const res = await app.request("/test");
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("OK");
  });

  it("should reject request without token when secret is configured", async () => {
    const secret = "test-secret-key";
    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(secret));
    app.get("/test", (c) => c.text("OK"));

    const res = await app.request("/test");
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("Missing token");
  });

  it("should reject request with invalid token format", async () => {
    const secret = "test-secret-key";
    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(secret));
    app.get("/test", (c) => c.text("OK"));

    const res = await app.request("/test?token=invalid-format");
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("Invalid token");
  });

  it("should reject request with invalid signature", async () => {
    const secret = "test-secret-key";
    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(secret));
    app.get("/test", (c) => c.text("OK"));

    // Token with wrong signature
    const res = await app.request("/test?token=1:3101:abc123:wrongsignature");
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("Invalid token");
  });

  it("should accept request with valid token", async () => {
    const secret = "test-secret-key";
    const userId = 1;
    const port = 3101;
    const randomPart = "abc123def456";

    const validToken = await generateToken(userId, port, randomPart, secret);

    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(secret));
    app.get("/test", (c) => c.text("OK"));

    const res = await app.request(`/test?token=${validToken}`);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("OK");
  });

  it("should accept request with valid token containing special characters", async () => {
    const secret = "test-secret-with-special!@#$";
    const userId = 42;
    const port = 9000;
    const randomPart = "a1b2c3d4e5f6";

    const validToken = await generateToken(userId, port, randomPart, secret);

    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(secret));
    app.get("/test", (c) => c.text("OK"));

    const res = await app.request(`/test?token=${encodeURIComponent(validToken)}`);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("OK");
  });

  it("should reject token generated with different secret", async () => {
    const correctSecret = "correct-secret";
    const wrongSecret = "wrong-secret";
    const userId = 1;
    const port = 3101;
    const randomPart = "abc123";

    // Generate token with wrong secret
    const invalidToken = await generateToken(userId, port, randomPart, wrongSecret);

    const app = new Hono();
    app.use("*", createTokenAuthMiddleware(correctSecret));
    app.get("/test", (c) => c.text("OK"));

    const res = await app.request(`/test?token=${invalidToken}`);
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("Invalid token");
  });
});