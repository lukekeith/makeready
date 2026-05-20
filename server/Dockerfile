# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first (for better caching)
COPY package*.json ./
RUN npm install

# Copy prisma schema and generate client
COPY prisma ./prisma/
RUN npx prisma generate

# Copy source code and build
COPY . .
RUN npm run build:only

# Download Atlas CLI (linux-amd64) for runtime migrations
RUN apk add --no-cache curl \
 && mkdir -p /app/bin \
 && curl -sSL -o /app/bin/atlas "https://release.ariga.io/atlas/atlas-community-linux-amd64-latest" \
 && chmod +x /app/bin/atlas

# Production stage
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY --from=builder /app/package*.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Copy built application and prisma client
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=builder /app/src/generated ./dist/generated

# Copy public folder if it exists
COPY --from=builder /app/public ./public

# Copy theme files for the loader and static serving
COPY --from=builder /app/themes ./themes

# Copy Atlas migration files + binary so deploys can apply pending migrations
COPY --from=builder /app/atlas ./atlas
COPY --from=builder /app/bin/atlas ./bin/atlas

# Set environment variables
ENV NODE_ENV=production

# Expose port
EXPOSE 3001

# Apply pending Atlas migrations, load themes, then start the server.
# Strip Prisma-specific query params (connection_limit, pool_timeout) from
# DATABASE_URL before passing to Atlas, which sends them to PostgreSQL raw.
CMD ["sh", "-c", "ATLAS_DB_URL=$(echo \"$DATABASE_URL\" | sed 's/[&?]connection_limit=[^&]*//g; s/[&?]pool_timeout=[^&]*//g') && cd atlas && ../bin/atlas migrate apply --env production --url \"$ATLAS_DB_URL\" && cd .. && node dist/scripts/load-themes.js && node dist/index.js"]
