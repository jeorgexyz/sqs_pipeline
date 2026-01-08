FROM elixir:1.14-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy application code
COPY config ./config
COPY lib ./lib

# Compile and build release
RUN MIX_ENV=prod mix compile && \
    MIX_ENV=prod mix release

# Create lightweight runtime image
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    openssl \
    ncurses-libs \
    libstdc++

WORKDIR /app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/sqs_pipeline ./

# Create output directory
RUN mkdir -p /app/output

# Environment variables
ENV MIX_ENV=prod
ENV LANG=C.UTF-8

# Expose any ports if needed (not required for this service)
# EXPOSE 4000

# Run the application
CMD ["/app/bin/sqs_pipeline", "start"]
