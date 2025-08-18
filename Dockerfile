# Build stage
FROM elixir:1.18-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm python3

# Set build environment
ENV MIX_ENV=prod

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

# Copy assets
COPY assets assets

# Build assets  
RUN cd assets && npm install && npm run build && cd ..

# Copy source code
COPY lib lib
COPY priv priv

# Compile and build release
RUN mix compile && \
    mix assets.deploy && \
    mix phx.digest && \
    mix release

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs

ENV MIX_ENV=prod
ENV PORT=4000
ENV RUBP_PORT=1982

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/rachel ./

# Expose ports
EXPOSE 4000 1982

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD nc -z localhost 4000 || exit 1

# Start the application
CMD ["bin/rachel", "start"]