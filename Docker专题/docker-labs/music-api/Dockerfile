ARG NODE_IMAGE=node:20-bookworm-slim
FROM ${NODE_IMAGE}

ENV NODE_ENV=production \
    TZ=Asia/Shanghai

WORKDIR /app

COPY package.json package-lock.json ./

# prepare 会调用只存在于 devDependencies 的 husky，生产镜像安装时跳过生命周期脚本。
RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force

COPY --chown=node:node . .

USER node

EXPOSE 3000

CMD ["node", "app.js"]
