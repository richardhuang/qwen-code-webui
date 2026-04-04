/**
 * Token authentication middleware for Open-ACE integration
 *
 * When --token-secret is configured, this middleware validates tokens
 * from URL query parameters to ensure requests come from authorized Open-ACE users.
 *
 * Token format: {user_id}:{port}:{random}:{signature}
 * Signature: SHA256({user_id}:{port}:{random}:{secret}).hexdigest()[:16]
 *
 * If --token-secret is not configured, the middleware skips validation,
 * allowing standalone usage without Open-ACE integration.
 */

import { createMiddleware } from "hono/factory";
import { logger } from "../utils/logger.ts";

/**
 * Computes SHA256 hash and returns hex string
 *
 * @param data Data to hash
 * @returns Hex string of the hash
 */
async function sha256Hex(data: string): Promise<string> {
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(data);

  // Use Web Crypto API (async version for Node.js compatibility)
  const hashBuffer = await crypto.subtle.digest("SHA-256", dataBuffer);
  const hashArray = new Uint8Array(hashBuffer);
  const hexHash = Array.from(hashArray)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return hexHash;
}

/**
 * Validates a token against the expected signature
 *
 * @param token Token string to validate
 * @param secret Secret key for signature verification
 * @returns True if token is valid, false otherwise
 */
async function validateToken(token: string, secret: string): Promise<boolean> {
  try {
    const parts = token.split(":");
    if (parts.length !== 4) {
      logger.app.warn("Invalid token format: expected 4 parts");
      return false;
    }

    const [userId, port, randomPart, signature] = parts;

    // Compute expected signature using same algorithm as Open-ACE
    const dataToSign = `${userId}:${port}:${randomPart}:${secret}`;
    const hexHash = await sha256Hex(dataToSign);
    const expectedSignature = hexHash.slice(0, 16);

    if (signature !== expectedSignature) {
      logger.app.warn("Token signature mismatch");
      return false;
    }

    logger.app.debug("Token validated successfully for user {userId}", {
      userId,
    });
    return true;
  } catch (error) {
    logger.app.error("Token validation error: {error}", { error });
    return false;
  }
}

/**
 * Creates token authentication middleware
 *
 * @param tokenSecret Secret key for token validation. If undefined or empty,
 *                    the middleware skips validation (standalone mode).
 * @returns Hono middleware function
 */
export function createTokenAuthMiddleware(tokenSecret?: string) {
  return createMiddleware(async (c, next) => {
    // Skip validation if no secret is configured (standalone mode)
    if (!tokenSecret) {
      await next();
      return;
    }

    // Get token from URL query parameter
    const token = c.req.query("token");

    if (!token) {
      logger.app.warn("Request rejected: missing token parameter");
      return c.text("Unauthorized: Missing token", 401);
    }

    // Validate token
    if (!(await validateToken(token, tokenSecret))) {
      logger.app.warn("Request rejected: invalid token");
      return c.text("Unauthorized: Invalid token", 401);
    }

    // Token is valid, proceed to next handler
    await next();
  });
}

/**
 * Type for context with token auth
 */
export type TokenAuthContext = {
  Variables: {
    tokenSecret?: string;
  };
};