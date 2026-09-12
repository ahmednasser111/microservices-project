# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

This root repo is a **Kong API Gateway orchestration layer** for two independent Node.js/TypeScript microservices. `auth-service/` and `chat-service/` are each their own git repository (they have their own `.git`, not registered as `.gitmodules` submodules) — they show up as untracked directories (`??`) in the root repo's `git status`. Treat commits inside those directories as belonging to their own repo/history; don't assume `git log`/`git diff` at the root will show their internal changes.

There is no frontend in this repository yet — `kong-routes.md`/README diagrams reference a "Frontend (React)" box, but no frontend code exists here. If a Next.js frontend is added, it will need its own service block in `docker-compose.yml` and a Kong route.

## Architecture

Root `docker-compose.yml` wires together:

- **auth-postgres** / **chat-postgres** — one Postgres 15 instance per service (separate DBs, separate volumes)
- **redis** — shared across both services (sessions for auth, pub/sub + cache for chat)
- **zookeeper** + **kafka** — shared event bus; auth-service produces `user.registered`-style events, chat-service consumes/produces chat events
- **kong-database** + **kong-migrations** + **kong** — Kong API Gateway (Postgres-backed, not DB-less). Proxy on `:8000`, Admin API on `:8001`
- **konga** — web UI for Kong admin, `:8002`
- **auth-service** (`:3001`) and **chat-service** (`:3002`) — the actual application services
- optional `dev` profile: `kafka-ui` (`:8081`), `redis-commander` (`:8083`)

Kong routes are **not** declarative config — they're created imperatively by POSTing to the Kong Admin API, either via `scripts/kong-setup.sh` / `scripts/kong-advanced.sh` or the raw `curl` commands in `kong-routes.md`. After `docker-compose up`, Kong has no routes configured until one of those scripts runs. Known routes: `/auth` → auth-service, `/chat` → chat-service, `/socket.io` → chat-service (Socket.IO, `strip_path=false`).

### auth-service (`auth-service/`)

Express 5 + TypeORM + PostgreSQL. JWT auth with Redis-backed sessions, Kafka event producer, Sentry, Swagger docs at `/docs`-style route, Winston logging. Entry point `src/app.ts` — note it lazily initializes the DB/Kafka connection on first request and **only calls `app.listen()` when not running on Vercel** (`process.env.VERCEL` check), because this service also has a `vercel.json` for serverless deployment as an alternative to the Docker path. Routes mount at `/api/v1/auth`.

### chat-service (`chat-service/`)

Express 4 + Prisma + PostgreSQL. Socket.IO for real-time messaging (auth'd via `middleware/socketAuth.ts`), Kafka consumer/producer via `services/kafka-service.ts`, Redis for pub/sub scaling, rate limiting, Sentry, Swagger docs. Two entry files: `src/app.ts` builds the Express app + HTTP server + `initializeServices()` (DB/Redis/Kafka/Socket.IO startup sequence), `src/index.ts` is the actual process entry that calls `server.listen()` and wires graceful shutdown. REST routes mount at `/api/messages`, `/api/users`, `/api/rooms`; Prisma schema/migrations live in `chat-service/prisma/`.

## Commands

### Whole stack (from repo root)

```bash
make quick-start        # docker-compose up -d + kong-setup.sh + kong-advanced.sh
make start               # start all services
make start-dev           # start with kafka-ui + redis-commander (dev profile)
make health              # curl health checks across gateway/auth/chat
make logs-auth           # docker-compose logs -f auth-service
make logs-chat           # docker-compose logs -f chat-service
make test-auth           # curl-based smoke test of auth endpoints through Kong
make test-chat           # curl-based smoke test of chat endpoints through Kong
make clean               # remove containers/volumes
```

Run `make help` for the full command list. Manual equivalent: `docker-compose up -d`, then `scripts/kong-setup.sh` and `scripts/kong-advanced.sh` once Postgres/Kong are healthy.

### auth-service (run from `auth-service/`)

```bash
yarn install
yarn dev              # ts-node-dev, hot reload
yarn build            # tsc -> dist/
yarn start            # ts-node src/app.ts (not dist — no separate prod start script)
yarn lint             # eslint --fix
yarn test             # jest
```

### chat-service (run from `chat-service/`)

```bash
yarn install
yarn dev              # tsx watch src/index.ts
yarn build            # tsc -p . -> dist/
yarn start            # node dist/index.js
yarn lint             # eslint . --max-warnings 0
yarn db:generate      # prisma generate
yarn db:migrate       # prisma migrate dev
yarn db:studio        # prisma studio
```

There is no `test` script in chat-service's package.json.

Both services require their own `.env` (see `.env.example` in each) with `DATABASE_URL`, `REDIS_URL`, `KAFKA_BROKER`, `JWT_SECRET`, `ALLOWED_ORIGINS`, `SENTRY_DSN`. `JWT_SECRET` must match between auth-service and chat-service since chat-service verifies tokens issued by auth-service.
