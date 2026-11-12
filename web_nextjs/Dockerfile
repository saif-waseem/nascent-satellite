# Multi-stage Dockerfile for Next.js Web Application
# Stage 1: Build
FROM node:20-alpine AS build

WORKDIR /app

COPY web_nextjs/package*.json ./
RUN npm ci

COPY web_nextjs/ ./
RUN npm run build

# Stage 2: Production Runner
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

COPY --from=build /app/package*.json ./
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/node_modules ./node_modules

EXPOSE 3000

CMD ["npm", "start"]
