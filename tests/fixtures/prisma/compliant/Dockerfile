# compliant fixture：生产部署用 migrate deploy（仅应用未执行迁移，无交互）
FROM node:22-slim
WORKDIR /app
COPY . .
RUN npm install
CMD npx prisma migrate deploy && node src/index.js
