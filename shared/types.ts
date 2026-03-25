export interface StreamResponse {
  type: "claude_json" | "error" | "done" | "aborted" | "control_request";
  data?: unknown; // SDKMessage object for claude_json type (Qwen SDK message)
  error?: string;
  controlRequest?: ControlRequestData;
}

// Control request types for tool approval
export interface ControlRequestData {
  requestId: string;
  sessionId: string;
  toolName: string;
  toolInput?: Record<string, unknown>;
  reason?: string;
  message?: string;
}

export interface ControlResponseRequest {
  requestId: string;
  sessionId: string;
  approved: boolean;
  reason?: string;
}

export interface ChatRequest {
  message: string;
  sessionId?: string;
  requestId: string;
  allowedTools?: string[];
  workingDirectory?: string;
  permissionMode?: "default" | "plan" | "auto-edit" | "yolo";
  model?: string;
}

// Model provider types
export interface ModelConfig {
  id: string;
  name: string;
  baseUrl?: string;
  envKey?: string;
  generationConfig?: {
    extra_body?: Record<string, unknown>;
    contextWindowSize?: number;
  };
}

export interface ModelsResponse {
  models: ModelConfig[];
}

export interface AbortRequest {
  requestId: string;
}

export interface ProjectInfo {
  path: string;
  encodedName: string;
}

export interface ProjectsResponse {
  projects: ProjectInfo[];
}

// Conversation history types
export interface ConversationSummary {
  sessionId: string;
  startTime: string;
  lastTime: string;
  messageCount: number;
  lastMessagePreview: string;
}

export interface HistoryListResponse {
  conversations: ConversationSummary[];
}

// Conversation history types
// Note: messages are typed as unknown[] to avoid frontend/backend dependency issues
// Frontend should cast to TimestampedSDKMessage[] (defined in frontend/src/types.ts)
export interface ConversationHistory {
  sessionId: string;
  messages: unknown[]; // TimestampedSDKMessage[] in practice, but avoiding frontend type dependency
  metadata: {
    startTime: string;
    endTime: string;
    messageCount: number;
  };
}
