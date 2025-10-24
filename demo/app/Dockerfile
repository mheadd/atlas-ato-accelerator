# NIST 800-53: SI-2 - Flaw Remediation
# Multi-stage build to reduce attack surface and image size

# Stage 1: Dependencies
FROM node:18-alpine AS dependencies

# Install security updates
RUN apk upgrade --no-cache

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including dev for potential build steps)
RUN npm ci --only=production && \
    npm cache clean --force

# Stage 2: Production
FROM node:18-alpine AS production

# NIST 800-53: SI-2 - Apply security updates
RUN apk upgrade --no-cache && \
    apk add --no-cache dumb-init

WORKDIR /app

# NIST 800-53: AC-6 - Least Privilege
# Create non-root user with specific UID/GID
# Use higher UID/GID to avoid conflicts with system users
RUN addgroup -g 10000 appuser && \
    adduser -D -u 10000 -G appuser appuser

# Copy dependencies from previous stage
COPY --from=dependencies --chown=appuser:appuser /app/node_modules ./node_modules

# Copy application code
COPY --chown=appuser:appuser package*.json ./
COPY --chown=appuser:appuser server.js ./

# NIST 800-53: SC-28 - Read-only root filesystem support
# Create directory for application logs with proper permissions
RUN mkdir -p /app/logs && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# NIST 800-53: SC-7 - Boundary Protection
# Expose only necessary port
EXPOSE 3000

# NIST 800-53: AU-2 - Health monitoring
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly (PID 1 problem)
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "server.js"]
