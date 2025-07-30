# Production Dockerfile
FROM node:22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache make gcc g++ libc-dev python3 py3-pip

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for build)
RUN npm install && npm cache clean --force

# Production stage
FROM node:22-alpine AS base

# Install dumb-init for proper signal handling and Python 3
RUN apk add --no-cache dumb-init python3 py3-pip

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Copy node_modules from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy built application
COPY dist/ ./dist/

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

# Change ownership of the app directory
RUN chown -R nestjs:nodejs /app
USER nestjs

# Expose port
EXPOSE 3001

# Use dumb-init for proper signal handling
ENTRYPOINT ["dumb-init", "--"]

# Start production server
CMD ["node", "dist/main.js"]