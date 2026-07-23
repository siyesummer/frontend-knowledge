ARG NODE_IMAGE=node:20-bookworm-slim

FROM ${NODE_IMAGE} AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . ./
RUN npm run build

FROM ${NODE_IMAGE} AS runtime

ENV NODE_ENV=production \
    MD_VIEWER_PORT=3001 \
    KNOWLEDGE_ROOT=/knowledge

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder --chown=node:node /app/server ./server
COPY --from=builder --chown=node:node /app/src/dist ./src/dist

USER node

EXPOSE 3001

CMD ["node", "server/index.js"]
