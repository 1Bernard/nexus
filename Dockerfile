# =============================================================================
# Nexus — Production Multi-Stage Dockerfile
# =============================================================================
#
# Stage 1 (builder): Compiles Elixir/Erlang release + JS/CSS assets.
# Stage 2 (runner):  Minimal Debian image containing only the compiled release.
#
# Third-party dependencies accounted for:
#   - TimescaleDB (Postgres): external service, connected via DATABASE_URL
#   - EventStore:             initialized via bin/init_db before first start
#   - EXLA / Nx / Bumblebee: XLA_TARGET=cpu fetches the correct native binary
#   - Massive FX WebSocket:   API key injected at runtime via MASSIVE_API_KEY
#   - Polygon WebSocket:      API key injected at runtime via POLYGON_API_KEY
#   - WebSockex:              compiled into the release; no extra OS deps needed
#
# Build:
#   docker build -t nexus .
#
# Run (via docker-compose):
#   docker compose up
# =============================================================================

# ---- Versions ----------------------------------------------------------------
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.1
ARG DEBIAN_VERSION=bookworm-20260223-slim

# PLATFORM NOTE: We pin to linux/amd64 explicitly.
# On Apple Silicon (M1/M2/M3), running arm64 would force EXLA to compile
# XLA C++ bindings from source, which requires 4-6GB RAM and kills Docker.
# amd64 downloads a pre-compiled 110MB XLA binary — fast, no compilation.
# Production Linux servers are x86_64, so this image is directly deployable.
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# =============================================================================
# STAGE 1 — Builder
# =============================================================================
FROM --platform=linux/amd64 ${BUILDER_IMAGE} AS builder

# -- OS Build Dependencies ----------------------------------------------------
# build-essential : C compiler for NIFs (Decimal, Wax, etc.)
# git             : used by some mix deps to fetch from git
# curl            : EXLA downloads the XLA binary via curl
RUN apt-get update -q && \
  apt-get install -y --no-install-recommends \
  build-essential \
  git \
  curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# -- Hex + Rebar --------------------------------------------------------------
RUN mix local.hex --force && \
  mix local.rebar --force

# -- Build Environment --------------------------------------------------------
ENV MIX_ENV=prod
# XLA_TARGET=cpu tells EXLA to download the pre-compiled CPU binary.
# For GPU hosts, set XLA_TARGET=cuda118 (or cuda120) via build arg.
# This MUST be set at compile time so Bumblebee/EXLA fetch the right artifact.
ENV XLA_TARGET=cpu
# Prevent EXLA from trying to build XLA from source (very slow, not needed).
ENV ELIXIR_ERL_OPTIONS="+JPperf true"

# -- Dependencies (cached separately for faster rebuilds) ---------------------
COPY mix.exs mix.lock ./
# Fetch only prod deps (test/dev tooling such as credo/dialyxir are excluded)
RUN mix deps.get --only $MIX_ENV

# -- Compile-time Config (must be present before deps.compile) ----------------
RUN mkdir config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

# -- Tailwind + ESBuild setup (downloads platform binaries) -------------------
RUN mix assets.setup

# -- Application Source -------------------------------------------------------
COPY priv priv
COPY lib lib
COPY assets assets

# -- Compile Application ------------------------------------------------------
RUN mix compile

# -- Compile & Digest Assets --------------------------------------------------
RUN mix assets.deploy

# -- Runtime Config (changes don't require re-compiling deps) -----------------
COPY config/runtime.exs config/

# -- Release Overlay Scripts --------------------------------------------------
COPY rel rel
# Make all overlay scripts executable BEFORE assembling the release.
# Without this, the final image has bin/server, bin/migrate, bin/init_db
# without the +x bit, causing 'Permission denied' at container startup.
RUN chmod +x rel/overlays/bin/*


# -- Assemble Release ---------------------------------------------------------
RUN mix release

# =============================================================================
# STAGE 2 — Runner (minimal production image)
# =============================================================================
FROM --platform=linux/amd64 ${RUNNER_IMAGE} AS final

# -- Runtime OS Libraries -----------------------------------------------------
# libstdc++6    : C++ standard library (EXLA / NIF dependencies)
# openssl       : TLS for HTTPS, WebSocket (Massive FX, Polygon)
# libncurses6   : Erlang shell / iex
# locales       : required for en_US.UTF-8 locale
# ca-certificates: trusted root CAs for outbound HTTPS/WSS connections
RUN apt-get update -q && \
  apt-get install -y --no-install-recommends \
  libstdc++6 \
  openssl \
  libncurses6 \
  locales \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# -- Locale -------------------------------------------------------------------
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# -- Working Directory ---------------------------------------------------------
WORKDIR /app
RUN chown nobody /app

# -- Runtime Environment Defaults ---------------------------------------------
ENV MIX_ENV=prod
ENV XLA_TARGET=cpu
# PHX_SERVER is set by the bin/server entrypoint script.

# -- Copy Release from Builder ------------------------------------------------
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/nexus ./

USER nobody

# -- Entrypoint ---------------------------------------------------------------
# bin/server sets PHX_SERVER=true and runs the release in foreground mode.
CMD ["/app/bin/server"]
