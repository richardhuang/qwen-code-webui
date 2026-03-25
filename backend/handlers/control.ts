import { Context } from "hono";
import type { ControlResponseRequest } from "../../shared/types.ts";
import { pendingControlRequests } from "./chat.ts";
import { logger } from "../utils/logger.ts";

/**
 * Handles POST /api/control/response requests
 * This endpoint receives user's approval/rejection for tool execution
 * @param c - Hono context object
 * @returns Response indicating success or failure
 */
export async function handleControlResponse(c: Context) {
  const response: ControlResponseRequest = await c.req.json();
  const { requestId, sessionId, approved, reason } = response;

  logger.chat.info(
    "Control response received: requestId={requestId}, sessionId={sessionId}, approved={approved}",
    { requestId, sessionId, approved },
  );

  // Get the pending control request
  const pendingRequest = pendingControlRequests.get(requestId);
  if (!pendingRequest) {
    logger.chat.warn("Control request not found: {requestId}", { requestId });
    return c.json({ success: false, error: "Control request not found" }, 404);
  }

  try {
    // Resolve the promise with the user's decision
    if (approved) {
      pendingRequest.resolve({
        behavior: "allow",
        updatedInput: pendingRequest.controlData.toolInput || {},
      });
    } else {
      pendingRequest.resolve({
        behavior: "deny",
        message: reason || "User rejected the tool execution",
        interrupt: false,
      });
    }

    // Remove the pending request after successful response
    pendingControlRequests.delete(requestId);

    logger.chat.info("Control response processed successfully: {requestId}", { requestId });
    return c.json({ success: true });
  } catch (error) {
    logger.chat.error("Failed to process control response: {error}", { error });
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
}

/**
 * Handles POST /api/control/cancel requests
 * This endpoint cancels a pending control request
 * @param c - Hono context object
 * @returns Response indicating success or failure
 */
export async function handleControlCancel(c: Context) {
  const { requestId } = await c.req.json();

  logger.chat.info(
    "Control cancel received: requestId={requestId}",
    { requestId },
  );

  // Get the pending control request
  const pendingRequest = pendingControlRequests.get(requestId);
  if (!pendingRequest) {
    return c.json({ success: false, error: "Control request not found" }, 404);
  }

  try {
    // Reject the promise to cancel the request
    pendingRequest.reject(new Error("User cancelled the request"));

    // Remove the pending request
    pendingControlRequests.delete(requestId);

    return c.json({ success: true });
  } catch (error) {
    logger.chat.error("Failed to cancel control request: {error}", { error });
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
}