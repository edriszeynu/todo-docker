FROM node:22-bookworm-slim AS build

WORKDIR /workspace/todo-app

RUN apt-get update \
  && apt-get install --no-install-recommends -y openssl \
  && rm -rf /var/lib/apt/lists/*

ENV DATABASE_URL="mongodb://127.0.0.1:27017/todo?replicaSet=rs0&directConnection=true"

COPY todo-app/package.json todo-app/package-lock.json ./
COPY todo-app/prisma.config.ts ./prisma.config.ts
COPY prisma/schema.prisma ../prisma/schema.prisma
RUN npm ci

COPY todo-app/ ./
RUN npm run build

FROM node:22-bookworm-slim AS production-dependencies

WORKDIR /app

RUN apt-get update \
  && apt-get install --no-install-recommends -y openssl \
  && rm -rf /var/lib/apt/lists/*

COPY todo-app/package.json todo-app/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

FROM node:22-bookworm-slim AS runner

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
ENV HOME=/tmp

WORKDIR /app

RUN apt-get update \
  && apt-get install --no-install-recommends -y openssl \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system --gid 1001 nodejs \
  && useradd --system --uid 1001 --gid nodejs nextjs

COPY --from=production-dependencies --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nextjs:nodejs /workspace/todo-app/.next ./.next
COPY --from=build --chown=nextjs:nodejs /workspace/todo-app/public ./public
COPY --from=build --chown=nextjs:nodejs /workspace/todo-app/next.config.ts ./next.config.ts
COPY --from=build --chown=nextjs:nodejs /workspace/todo-app/package.json ./package.json
COPY --from=build --chown=nextjs:nodejs /workspace/todo-app/node_modules/.prisma/client ./node_modules/.prisma/client

USER nextjs

EXPOSE 3000

CMD ["npm", "run", "start"]
