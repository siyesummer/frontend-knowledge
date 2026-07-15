ARG NODE_IMAGE=node:20-bookworm-slim
FROM ${NODE_IMAGE}

ARG NPM_REGISTRY=https://registry.npmmirror.com

ENV NODE_ENV=production \
    TZ=Asia/Shanghai

WORKDIR /app

COPY package.json package.json

RUN npm install --omit=dev --ignore-scripts --registry=${NPM_REGISTRY} \
    && npm cache clean --force

COPY --chown=node:node server.js server.js
COPY --chown=node:node config ./config

USER node

EXPOSE 3030

CMD ["node", "server.js"]
