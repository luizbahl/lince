# Dev/test toolbox shared by all Elixir services (mix test, format, credo).
# Versions match the local mise setup: Elixir 1.20.4 / OTP 29.
FROM elixir:1.20.4-otp-29

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential inotify-tools \
 && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app
