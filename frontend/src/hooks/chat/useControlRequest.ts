import { useState, useCallback } from "react";
import type { ControlRequestDialog } from "../../types";

const CONTROL_API_URL = "/api/control";

/**
 * Hook for managing control request dialog state and API calls
 */
export function useControlRequest() {
  const [controlRequestDialog, setControlRequestDialog] =
    useState<ControlRequestDialog | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  /**
   * Show the control request dialog
   */
  const showControlRequestDialog = useCallback(
    (request: ControlRequestDialog) => {
      setControlRequestDialog(request);
    },
    [],
  );

  /**
   * Close the control request dialog
   */
  const closeControlRequestDialog = useCallback(() => {
    setControlRequestDialog(null);
  }, []);

  /**
   * Send control response to the backend
   */
  const sendControlResponse = useCallback(
    async (requestId: string, sessionId: string, approved: boolean, reason?: string) => {
      setIsSubmitting(true);
      try {
        const response = await fetch(`${CONTROL_API_URL}/response`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            requestId,
            sessionId,
            approved,
            reason,
          }),
        });

        if (!response.ok) {
          const error = await response.json();
          throw new Error(error.error || "Failed to send control response");
        }

        return await response.json();
      } catch (error) {
        console.error("Failed to send control response:", error);
        throw error;
      } finally {
        setIsSubmitting(false);
      }
    },
    [],
  );

  /**
   * Approve the control request
   */
  const approveControlRequest = useCallback(async () => {
    if (!controlRequestDialog) return;

    try {
      await sendControlResponse(
        controlRequestDialog.requestId,
        controlRequestDialog.sessionId,
        true,
        "User approved",
      );
      closeControlRequestDialog();
    } catch (error) {
      console.error("Failed to approve control request:", error);
    }
  }, [controlRequestDialog, sendControlResponse, closeControlRequestDialog]);

  /**
   * Reject the control request
   */
  const rejectControlRequest = useCallback(async () => {
    if (!controlRequestDialog) return;

    try {
      await sendControlResponse(
        controlRequestDialog.requestId,
        controlRequestDialog.sessionId,
        false,
        "User rejected",
      );
      closeControlRequestDialog();
    } catch (error) {
      console.error("Failed to reject control request:", error);
    }
  }, [controlRequestDialog, sendControlResponse, closeControlRequestDialog]);

  return {
    controlRequestDialog,
    isSubmitting,
    showControlRequestDialog,
    closeControlRequestDialog,
    approveControlRequest,
    rejectControlRequest,
    sendControlResponse,
  };
}