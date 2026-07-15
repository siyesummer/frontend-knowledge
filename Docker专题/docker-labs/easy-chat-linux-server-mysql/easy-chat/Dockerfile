ARG NODE_IMAGE=node:20-bookworm-slim
FROM ${NODE_IMAGE}

WORKDIR /app

COPY package.json package.json

RUN npm install --omit=dev --registry=https://registry.npmmirror.com

COPY server.js server.js
COPY config ./config

EXPOSE 3030

CMD ["node", "server.js"]
