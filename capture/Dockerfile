FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.mjs ./
COPY dist/ ./dist/
COPY fixtures/ ./fixtures/
COPY runners/client/devices.mjs ./runners/client/devices.mjs

ENV NODE_ENV=production
ENV RAILWAY=true

EXPOSE 3000
CMD ["node", "server.mjs"]
