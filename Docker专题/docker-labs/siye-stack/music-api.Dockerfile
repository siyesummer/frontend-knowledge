ARG NODE_IMAGE=node:20-bookworm-slim
FROM ${NODE_IMAGE}

ARG NPM_REGISTRY=https://registry.npmmirror.com

ENV NODE_ENV=production \
    TZ=Asia/Shanghai

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev --ignore-scripts --registry=${NPM_REGISTRY} \
    && npm cache clean --force

COPY --chown=node:node . .

USER node

EXPOSE 3000

CMD ["node", "app.js"]
