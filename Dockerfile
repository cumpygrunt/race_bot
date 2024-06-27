FROM elixir:1.15-slim AS build

ENV MIX_ENV=prod

RUN apt-get update && \
    apt-get install -y build-essential git npm && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Fetch dependencies
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
RUN mix deps.get --only "${MIX_ENV}"

# Copy static configs and compile dependencies
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Build assets and code
COPY priv priv
COPY lib lib
COPY assets assets
COPY tsconfig.json package*json ./
RUN mix assets.setup && \
    mix assets.deploy && \
    mix compile

# Create release
COPY config/runtime.exs config/
RUN mix release

# =================================================

FROM debian:12-slim

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

ENV MIX_ENV=prod

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN useradd --create-home --uid 1000 app

WORKDIR /app
RUN chown app /app

COPY --from=build --chown=app:root /app/_build/${MIX_ENV}/rel/f1bot /app/
COPY entrypoint.sh scripts LICENSE.md /app/

# Entrypoint drops privileges to the `app` user
USER root

# Explicitly invoke `bash` to ensure that the entrypoint script can
# run even without the `execute` bit set.
# This happens when the repo is cloned on a Windows filesystem. 
CMD ["/bin/bash", "/app/entrypoint.sh"]
