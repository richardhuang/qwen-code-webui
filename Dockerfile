# ============================================
# Stage 1: Build Frontend
# Use BUILDPLATFORM to build on native architecture (avoids QEMU issues with esbuild)
# ============================================
FROM --platform=$BUILDPLATFORM node:20-alpine AS frontend-builder

# Install build dependencies for native modules
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy shared types first
COPY shared/ ./shared/

WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm ci

# Copy frontend source
COPY frontend/ ./

# Build frontend
RUN npm run build

# ============================================
# Stage 2: Build Backend
# Use BUILDPLATFORM to build on native architecture (avoids QEMU issues)
# ============================================
FROM --platform=$BUILDPLATFORM node:20-alpine AS backend-builder

WORKDIR /app

# Copy shared types
COPY shared/ ./shared/

WORKDIR /app/backend

# Copy backend package files
COPY backend/package*.json ./

# Install dependencies (including devDependencies for build)
RUN npm ci

# Copy backend source
COPY backend/ ./

# Copy frontend build output (will be used by copy-frontend.js)
COPY --from=frontend-builder /app/frontend/dist ../frontend/dist

# Generate version and build backend
RUN node scripts/generate-version.js && \
    npm run build:bundle && \
    npm run build:static

# ============================================
# Stage 3: Production Runtime
# ============================================
FROM node:20-alpine AS runtime

# Proxy support (pass with --build-arg HTTP_PROXY=...)
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}

# Install Qwen Code CLI
RUN npm install -g @qwen-code/qwen-code

# Clear proxy env vars after install
ENV HTTP_PROXY=
ENV HTTPS_PROXY=

WORKDIR /app

# Copy built backend from builder
COPY --from=backend-builder /app/backend/dist ./dist
COPY --from=backend-builder /app/backend/node_modules ./node_modules
COPY --from=backend-builder /app/backend/package.json ./

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

# Start the application
CMD ["node", "dist/cli/node.js"]