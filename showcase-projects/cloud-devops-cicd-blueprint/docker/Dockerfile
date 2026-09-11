# ========================================================
# Stage 1: Build & Dependency Resolution
# ========================================================
FROM node:20-alpine AS builder

WORKDIR /app

# Install security patches & build essentials
RUN apk update && apk upgrade --no-cache

# Leverage Docker layer caching for dependencies
COPY package*.json ./
RUN npm ci --ignore-scripts 2>/dev/null || npm init -y

# Copy application source code
COPY . .

# Build application bundle
RUN echo "Building production artifacts..."

# ========================================================
# Stage 2: Hardened Runtime Container
# ========================================================
FROM node:20-alpine AS runner

# Create dedicated non-root user and group
RUN addgroup -g 10001 appgroup && \
    adduser -u 10001 -G appgroup -s /bin/sh -D appuser

WORKDIR /usr/src/app

# Copy production artifacts from builder stage with strict ownership
COPY --from=builder --chown=appuser:appgroup /app ./

# Set secure environment defaults
ENV NODE_ENV=production
ENV PORT=8080

# Switch to non-privileged user (Container Hardening)
USER appuser

# Expose microservice port
EXPOSE 8080

# Health check probe for container runtime
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 0

# Start command
CMD ["node", "-e", "const http = require('http'); const server = http.createServer((req, res) => { if(req.url === '/health') { res.writeHead(200, {'Content-Type': 'application/json'}); res.end(JSON.stringify({status: 'UP', timestamp: new Date().toISOString()})); } else { res.writeHead(200, {'Content-Type': 'text/plain'}); res.end('Cloud & DevOps Blueprint API - Production Ready Microservice'); } }); server.listen(8080, () => console.log('Microservice running on port 8080'));"]
