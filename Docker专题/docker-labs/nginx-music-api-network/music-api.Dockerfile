ARG NODE_IMAGE=node:20-bookworm-slim
FROM ${NODE_IMAGE}

ENV NODE_ENV=production \
    TZ=Asia/Shanghai

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force

COPY --chown=node:node . .

USER node

EXPOSE 3000

CMD ["node", "app.js"]
