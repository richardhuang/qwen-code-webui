import { useState, useCallback, useRef } from "react";
import type { PermissionMode } from "../../types";

interface PermissionRequest {
  isOpen: boolean;
  toolName: string;
  patterns: string[];
  toolUseId: string;
}

interface PlanModeRequest {
  isOpen: boolean;
  planContent: string;
}

interface UsePermissionsOptions {
  onPermissionModeChange?: (mode: PermissionMode) => void;
}

/**
 * Configuration for loop detection
 */
interface LoopDetectionConfig {
  /** Maximum consecutive denials before triggering protection */
  maxConsecutiveDenials: number;
  /** Time window in ms to reset the counter (5 minutes) */
  resetWindowMs: number;
  /** Tools to exclude from loop detection (always allowed to retry) */
  excludedTools: Set<string>;
}

const DEFAULT_LOOP_DETECTION_CONFIG: LoopDetectionConfig = {
  maxConsecutiveDenials: 3,
  resetWindowMs: 5 * 60 * 1000, // 5 minutes
  excludedTools: new Set(["exit_plan_mode"]),
};

/**
 * Build a message to break the AI out of a thinking loop
 */
function buildLoopDetectedMessage(): string {
  return `[SYSTEM: Loop Detection Triggered]

The system has detected that you are in a potential infinite loop of tool permission denials.

**IMPORTANT: Stop retrying the same action.**

Instead, please:
1. Explain to the user what you were trying to do
2. Ask the user if they want to try a different approach

Do not attempt to call the same tool again without user confirmation.`;
}

export function usePermissions(options: UsePermissionsOptions = {}) {
  const { onPermissionModeChange } = options;
  const [allowedTools, setAllowedTools] = useState<string[]>([]);
  const [permissionRequest, setPermissionRequest] =
    useState<PermissionRequest | null>(null);
  const [planModeRequest, setPlanModeRequest] =
    useState<PlanModeRequest | null>(null);

  // New state for inline permission system
  const [isPermissionMode, setIsPermissionMode] = useState(false);

  // Loop detection state (using refs to avoid re-renders)
  const consecutiveDenialsRef = useRef(0);
  const lastDenialTimeRef = useRef(0);
  const lastDeniedToolRef = useRef<string>("");
  const loopDetectionConfigRef = useRef(DEFAULT_LOOP_DETECTION_CONFIG);

  const showPermissionRequest = useCallback(
    (toolName: string, patterns: string[], toolUseId: string) => {
      setPermissionRequest({
        isOpen: true,
        toolName,
        patterns,
        toolUseId,
      });
      // Enable inline permission mode
      setIsPermissionMode(true);
    },
    [],
  );

  const closePermissionRequest = useCallback(() => {
    setPermissionRequest(null);
    // Disable inline permission mode
    setIsPermissionMode(false);
  }, []);

  const showPlanModeRequest = useCallback((planContent: string) => {
    setPlanModeRequest({
      isOpen: true,
      planContent,
    });
    setIsPermissionMode(true);
  }, []);

  const closePlanModeRequest = useCallback(() => {
    setPlanModeRequest(null);
    setIsPermissionMode(false);
  }, []);

  const allowToolTemporary = useCallback(
    (pattern: string, baseTools?: string[]) => {
      const currentAllowedTools = baseTools || allowedTools;
      return [...currentAllowedTools, pattern];
    },
    [allowedTools],
  );

  const allowToolPermanent = useCallback(
    (pattern: string, baseTools?: string[]) => {
      const currentAllowedTools = baseTools || allowedTools;
      const updatedAllowedTools = [...currentAllowedTools, pattern];
      setAllowedTools(updatedAllowedTools);
      return updatedAllowedTools;
    },
    [allowedTools],
  );

  const resetPermissions = useCallback(() => {
    setAllowedTools([]);
  }, []);

  // Helper function to update permission mode based on user action
  const updatePermissionMode = useCallback(
    (mode: PermissionMode) => {
      onPermissionModeChange?.(mode);
    },
    [onPermissionModeChange],
  );

  /**
   * Record a tool denial for loop detection
   */
  const recordDenial = useCallback((toolName: string): string | null => {
    const now = Date.now();
    const config = loopDetectionConfigRef.current;

    // Reset counter if outside the time window
    if (now - lastDenialTimeRef.current > config.resetWindowMs) {
      consecutiveDenialsRef.current = 0;
    }

    // Skip loop detection for excluded tools
    if (config.excludedTools.has(toolName)) {
      return null;
    }

    // Check if same tool as last denial
    if (lastDeniedToolRef.current === toolName) {
      consecutiveDenialsRef.current++;
    } else {
      consecutiveDenialsRef.current = 1;
      lastDeniedToolRef.current = toolName;
    }

    lastDenialTimeRef.current = now;

    // Check if we've exceeded the threshold
    if (consecutiveDenialsRef.current >= config.maxConsecutiveDenials) {
      consecutiveDenialsRef.current = 0; // Reset after triggering
      return buildLoopDetectedMessage();
    }

    return null;
  }, []);

  /**
   * Reset the denial counter (e.g., when a tool is approved)
   */
  const resetDenialCounter = useCallback(() => {
    consecutiveDenialsRef.current = 0;
    lastDeniedToolRef.current = "";
  }, []);

  return {
    allowedTools,
    permissionRequest,
    showPermissionRequest,
    closePermissionRequest,
    allowToolTemporary,
    allowToolPermanent,
    resetPermissions,
    isPermissionMode,
    setIsPermissionMode,
    planModeRequest,
    showPlanModeRequest,
    closePlanModeRequest,
    updatePermissionMode,
    // Loop detection
    recordDenial,
    resetDenialCounter,
  };
}
