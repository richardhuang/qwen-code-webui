import { Context } from "hono";
import {
  query,
  type PermissionMode,
  type CanUseTool,
  type ToolInput,
  type PermissionResult,
  type PermissionSuggestion,
} from "@qwen-code/sdk";
import type {
  ChatRequest,
  StreamResponse,
  ControlRequestData,
} from "../../shared/types.ts";
import { logger } from "../utils/logger.ts";

// Store pending control requests for each session
// Key: requestId, Value: { resolve, reject, controlData }
export const pendingControlRequests = new Map<
  string,
  {
    resolve: (result: PermissionResult) => void;
    reject: (error: Error) => void;
    controlData: ControlRequestData;
  }
>();

// Counter for generating unique request IDs
let controlRequestCounter = 0;

/**
 * Maps UI permission mode to Qwen SDK permission mode
 * Qwen SDK uses 'auto-edit' instead of 'acceptEdits'
 */
function mapPermissionMode(mode?: string): PermissionMode | undefined {
  if (!mode) return undefined;
  if (mode === "acceptEdits") {
    return "auto-edit";
  }
  // All other modes (default, plan, auto-edit, yolo) are passed through
  return mode as PermissionMode;
}

/**
 * Creates a canUseTool callback that yields control requests to the frontend
 * @param sessionId - Session ID for the conversation
 * @param yieldControlRequest - Function to yield control request to stream
 * @returns CanUseTool callback function
 */
function createCanUseToolCallback(
  sessionId: string,
  yieldControlRequest: (data: ControlRequestData) => void,
): CanUseTool {
  return async (
    toolName: string,
    input: ToolInput,
    options: { signal: AbortSignal; suggestions?: PermissionSuggestion[] | null },
  ): Promise<PermissionResult> => {
    const requestId = `control-${Date.now()}-${++controlRequestCounter}`;

    logger.chat.info("Tool approval requested: {toolName}", { toolName, requestId });

    const controlData: ControlRequestData = {
      requestId,
      sessionId,
      toolName,
      toolInput: input,
      message: `The AI wants to use the "${toolName}" tool. Do you want to allow this?`,
    };

    // Create a promise that will be resolved when the user responds
    return new Promise<PermissionResult>((resolve, reject) => {
      // Store the resolve/reject functions for later use
      pendingControlRequests.set(requestId, {
        resolve,
        reject,
        controlData,
      });

      // Yield the control request to the frontend
      yieldControlRequest(controlData);

      // Handle abort signal
      const abortHandler = () => {
        pendingControlRequests.delete(requestId);
        reject(new Error("Request aborted"));
      };
      options.signal.addEventListener("abort", abortHandler);
    });
  };
}

/**
 * Executes a Qwen command and yields streaming responses
 * @param message - User message or command
 * @param requestId - Unique request identifier for abort functionality
 * @param requestAbortControllers - Shared map of abort controllers
 * @param cliPath - Path to actual CLI script (detected by validateQwenCli)
 * @param sessionId - Optional session ID for conversation continuity
 * @param allowedTools - Optional array of allowed tool names
 * @param workingDirectory - Optional working directory for Qwen execution
 * @param permissionMode - Optional permission mode for Qwen execution
 * @param model - Optional model to use for the query
 * @returns AsyncGenerator yielding StreamResponse objects
 */
async function* executeQwenCommand(
  message: string,
  requestId: string,
  requestAbortControllers: Map<string, AbortController>,
  cliPath: string,
  sessionId?: string,
  allowedTools?: string[],
  workingDirectory?: string,
  permissionMode?: string,
  model?: string,
): AsyncGenerator<StreamResponse> {
  let abortController: AbortController;

  // Queue for control requests
  const controlRequestQueue: ControlRequestData[] = [];

  // Flag to signal when a control request is added
  const controlRequestSignal = { pending: false };

  // Function to add control request to queue
  const enqueueControlRequest = (data: ControlRequestData) => {
    controlRequestQueue.push(data);
    controlRequestSignal.pending = true;
  };

  try {
    // Process commands that start with '/'
    let processedMessage = message;
    if (message.startsWith("/")) {
      // Remove the '/' and send just the command
      processedMessage = message.substring(1);
    }

    // Create and store AbortController for this request
    abortController = new AbortController();
    requestAbortControllers.set(requestId, abortController);

    // Log permission mode for debugging
    const mappedPermissionMode = permissionMode ? mapPermissionMode(permissionMode) : undefined;
    logger.chat.debug(
      "Executing Qwen query with permissionMode: {permissionMode} (mapped: {mappedPermissionMode})",
      { permissionMode, mappedPermissionMode },
    );

    // Create canUseTool callback for default permission mode
    const canUseTool = mappedPermissionMode === "default"
      ? createCanUseToolCallback(sessionId || "", enqueueControlRequest)
      : undefined;

    // Start the query in a separate async context
    const queryIterator = query({
      prompt: processedMessage,
      options: {
        abortController,
        pathToQwenExecutable: cliPath,
        ...(sessionId ? { resume: sessionId } : {}),
        ...(allowedTools ? { allowedTools } : {}),
        ...(workingDirectory ? { cwd: workingDirectory } : {}),
        ...(mappedPermissionMode ? { permissionMode: mappedPermissionMode } : {}),
        ...(model ? { model } : {}),
        ...(canUseTool ? { canUseTool } : {}),
        // Disable timeout for canUseTool callback - user should have unlimited time to respond
        // Set to 100 years to effectively disable the timeout
        timeout: {
          canUseTool: 3153600000000, // 100 years - effectively no timeout for user permission response
        },
      },
    })[Symbol.asyncIterator]();

    // Process messages and control requests
    // Use Promise.race to handle control requests immediately
    while (true) {
      // Check for control requests first (non-blocking)
      while (controlRequestQueue.length > 0) {
        const controlData = controlRequestQueue.shift()!;
        logger.chat.debug("Yielding control request: {requestId}", { requestId: controlData.requestId });
        yield {
          type: "control_request",
          controlRequest: controlData,
        };
      }

      // Reset the signal
      controlRequestSignal.pending = false;

      // Create a promise that resolves when a control request is added
      const controlRequestPromise = new Promise<void>((resolve) => {
        const checkInterval = setInterval(() => {
          if (controlRequestSignal.pending || controlRequestQueue.length > 0) {
            clearInterval(checkInterval);
            resolve();
          }
        }, 50); // Check every 50ms
      });

      // Create a promise for the next SDK message
      const nextPromise = queryIterator.next();

      // Race between SDK message and control request
      const result = await Promise.race([
        nextPromise.then((r) => ({ type: 'sdk' as const, result: r })),
        controlRequestPromise.then(() => ({ type: 'control' as const })),
      ]);

      if (result.type === 'control') {
        // A control request was added, yield it
        while (controlRequestQueue.length > 0) {
          const controlData = controlRequestQueue.shift()!;
          logger.chat.debug("Yielding control request: {requestId}", { requestId: controlData.requestId });
          yield {
            type: "control_request",
            controlRequest: controlData,
          };
        }
        // Continue the loop to wait for SDK message
        continue;
      }

      // SDK message received
      const { done, value: sdkMessage } = result.result;

      // Check for control requests again after getting SDK message
      while (controlRequestQueue.length > 0) {
        const controlData = controlRequestQueue.shift()!;
        logger.chat.debug("Yielding control request: {requestId}", { requestId: controlData.requestId });
        yield {
          type: "control_request",
          controlRequest: controlData,
        };
      }

      if (done) {
        // Yield any remaining control requests
        while (controlRequestQueue.length > 0) {
          const controlData = controlRequestQueue.shift()!;
          yield {
            type: "control_request",
            controlRequest: controlData,
          };
        }
        break;
      }

      // Debug logging of raw SDK messages with detailed content
      logger.chat.debug("Qwen SDK Message: {sdkMessage}", { sdkMessage });

      yield {
        type: "claude_json",
        data: sdkMessage,
      };
    }

    yield { type: "done" };
  } catch (error) {
    // Check if error is due to abort
    // TODO: Re-enable when AbortError is properly exported from Qwen SDK
    // if (error instanceof AbortError) {
    //   yield { type: "aborted" };
    // } else {
    {
      logger.chat.error("Qwen Code execution failed: {error}", { error });
      yield {
        type: "error",
        error: error instanceof Error ? error.message : String(error),
      };
    }
  } finally {
    // Clean up AbortController from map
    if (requestAbortControllers.has(requestId)) {
      requestAbortControllers.delete(requestId);
    }
  }
}

/**
 * Handles POST /api/chat requests with streaming responses
 * @param c - Hono context object with config variables
 * @param requestAbortControllers - Shared map of abort controllers
 * @returns Response with streaming NDJSON
 */
export async function handleChatRequest(
  c: Context,
  requestAbortControllers: Map<string, AbortController>,
) {
  const chatRequest: ChatRequest = await c.req.json();
  const { cliPath } = c.var.config;

  logger.chat.debug(
    "Received chat request {*}",
    chatRequest as unknown as Record<string, unknown>,
  );
  logger.chat.debug(
    "Chat request permissionMode: {permissionMode}",
    { permissionMode: chatRequest.permissionMode },
  );

  const stream = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of executeQwenCommand(
          chatRequest.message,
          chatRequest.requestId,
          requestAbortControllers,
          cliPath, // Use detected CLI path from validateQwenCli
          chatRequest.sessionId,
          chatRequest.allowedTools,
          chatRequest.workingDirectory,
          chatRequest.permissionMode,
          chatRequest.model,
        )) {
          const data = JSON.stringify(chunk) + "\n";
          controller.enqueue(new TextEncoder().encode(data));
        }
        controller.close();
      } catch (error) {
        const errorResponse: StreamResponse = {
          type: "error",
          error: error instanceof Error ? error.message : String(error),
        };
        controller.enqueue(
          new TextEncoder().encode(JSON.stringify(errorResponse) + "\n"),
        );
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "application/x-ndjson",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}