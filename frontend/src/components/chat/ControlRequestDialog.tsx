import { useCallback, useEffect } from "react";
import type { ControlRequestDialog as ControlRequestDialogType } from "../../types";

interface ControlRequestDialogProps {
  request: ControlRequestDialogType | null;
  onApprove: (requestId: string, sessionId: string) => Promise<void>;
  onReject: (requestId: string, sessionId: string) => Promise<void>;
  onClose: () => void;
}

/**
 * Dialog component for tool approval requests
 * Displays when the AI needs user confirmation to execute a tool in default permission mode
 */
export function ControlRequestDialog({
  request,
  onApprove,
  onReject,
  onClose,
}: ControlRequestDialogProps) {
  const handleApprove = useCallback(async () => {
    if (!request) return;
    await onApprove(request.requestId, request.sessionId);
    onClose();
  }, [request, onApprove, onClose]);

  const handleReject = useCallback(async () => {
    if (!request) return;
    await onReject(request.requestId, request.sessionId);
    onClose();
  }, [request, onReject, onClose]);

  // Handle keyboard shortcuts
  useEffect(() => {
    if (!request || !request.isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Enter") {
        e.preventDefault();
        handleApprove();
      } else if (e.key === "Escape") {
        e.preventDefault();
        handleReject();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [request, handleApprove, handleReject]);

  if (!request || !request.isOpen) return null;

  // Format tool input for display
  const formatToolInput = (input: Record<string, unknown> | undefined): string => {
    if (!input) return "";
    try {
      return JSON.stringify(input, null, 2);
    } catch {
      return String(input);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="bg-white dark:bg-slate-800 rounded-xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden border border-slate-200 dark:border-slate-700">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center">
              <svg
                className="w-5 h-5 text-amber-600 dark:text-amber-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
            </div>
            <div>
              <h2 className="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Tool Approval Required
              </h2>
              <p className="text-sm text-slate-500 dark:text-slate-400">
                The AI wants to execute a tool
              </p>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="px-6 py-4 space-y-4">
          {/* Tool Name */}
          <div>
            <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Tool
            </label>
            <div className="px-3 py-2 bg-slate-100 dark:bg-slate-700 rounded-lg font-mono text-sm text-slate-900 dark:text-slate-100">
              {request.toolName}
            </div>
          </div>

          {/* Reason/Message */}
          {request.message && (
            <div>
              <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Message
              </label>
              <div className="px-3 py-2 bg-slate-100 dark:bg-slate-700 rounded-lg text-sm text-slate-900 dark:text-slate-100">
                {request.message}
              </div>
            </div>
          )}

          {/* Tool Input */}
          {request.toolInput && Object.keys(request.toolInput).length > 0 && (
            <div>
              <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Input
              </label>
              <pre className="px-3 py-2 bg-slate-100 dark:bg-slate-700 rounded-lg text-sm text-slate-900 dark:text-slate-100 overflow-auto max-h-40 font-mono">
                {formatToolInput(request.toolInput)}
              </pre>
            </div>
          )}

          {/* Warning */}
          <div className="flex items-start gap-2 p-3 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-800">
            <svg
              className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <p className="text-sm text-amber-700 dark:text-amber-300">
              Approving will allow the AI to execute this tool. Make sure you trust the
              requested action before approving.
            </p>
          </div>
        </div>

        {/* Actions */}
        <div className="px-6 py-4 border-t border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 flex justify-end gap-3">
          <button
            onClick={handleReject}
            className="px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-600 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 dark:focus:ring-offset-slate-800 transition-colors flex items-center gap-2"
          >
            Reject
            <kbd className="px-1.5 py-0.5 text-xs bg-slate-200 dark:bg-slate-600 rounded">Esc</kbd>
          </button>
          <button
            onClick={handleApprove}
            className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 dark:focus:ring-offset-slate-800 transition-colors flex items-center gap-2"
          >
            Approve
            <kbd className="px-1.5 py-0.5 text-xs bg-blue-500 rounded">Enter</kbd>
          </button>
        </div>
      </div>
    </div>
  );
}