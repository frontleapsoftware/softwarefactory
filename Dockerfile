# syntax=docker/dockerfile:1
# Production image for Mastra Factory (Coolify / any Docker host).
# Build: docker build -t mastra-factory .
# Run:   Coolify compose (docker-compose.coolify.yml) or:
#        docker run --rm -p 4111:4111 -e MASTRA_HOST=0.0.0.0 -e DATABASE_URL=... mastra-factory

FROM node:22-bookworm-slim AS builder

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY package.json .npmrc ./
COPY pnpm-workspace.yaml ./
COPY tsconfig.json ./
COPY .env.schema ./

# No lockfile in the template — install from package.json.
RUN npm install

COPY src ./src

ENV NODE_ENV=production
ENV NODE_OPTIONS=--max-old-space-size=4096

RUN npx mastra build --dir src/mastra

# ---------------------------------------------------------------------------

FROM node:22-bookworm-slim AS runner

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1001 --shell /usr/sbin/nologin mastra \
  && mkdir -p /data/sandboxes \
  && chown -R mastra:mastra /data

# `.mastra/output` is self-contained (index.mjs + production node_modules).
COPY --from=builder --chown=mastra:mastra /app/.mastra/output ./

USER mastra

ENV NODE_ENV=production
ENV PORT=4111
ENV MASTRA_HOST=0.0.0.0
ENV MASTRA_SKIP_DOTENV=1
ENV MASTRACODE_LOCAL_SANDBOX_ROOT=/data/sandboxes

EXPOSE 4111

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD curl -fsS http://127.0.0.1:4111/health || exit 1

CMD ["node", "index.mjs"]
