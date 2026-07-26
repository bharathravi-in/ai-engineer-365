# SkillMap — single-image deploy: builds the React app and serves it from the
# Node API (one container, one origin). Build with the compose file or:
#   docker build -t skillmap \
#     --build-arg VITE_SUPABASE_URL=... --build-arg VITE_SUPABASE_ANON_KEY=... .

# --- 1. Build the frontend (Vite inlines VITE_* at build time) ---------------
FROM node:22-alpine AS webbuild
WORKDIR /web
COPY app/package*.json ./
RUN npm ci
COPY app/ ./
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ARG VITE_API_URL=/api
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL \
    VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY \
    VITE_API_URL=$VITE_API_URL
RUN npm run build

# --- 2. Runtime: API server + built static frontend --------------------------
FROM node:22-alpine AS runtime
WORKDIR /srv
ENV NODE_ENV=production \
    PORT=8787 \
    STATIC_DIR=/srv/public
COPY server/package*.json ./
RUN npm ci --omit=dev
COPY server/ ./
COPY --from=webbuild /web/dist ./public
EXPOSE 8787
# Basic container healthcheck against the liveness probe.
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8787/health >/dev/null 2>&1 || exit 1
CMD ["npm", "start"]
