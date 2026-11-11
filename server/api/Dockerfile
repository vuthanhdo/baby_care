# Node runs the TypeScript sources directly (type stripping), so there is no build step.
FROM node:24-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY src ./src
COPY templates ./templates
USER node
EXPOSE 8080
CMD ["node", "src/main.ts"]
