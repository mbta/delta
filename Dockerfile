# From https://hub.docker.com/r/hexpm/elixir/tags
FROM hexpm/elixir:1.14.2-erlang-25.2-alpine-3.17.0 AS builder

WORKDIR /root

# Install Hex+Rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# Install git
RUN apk --update add git make

ENV MIX_ENV=prod

WORKDIR /root

ADD mix.exs mix.exs
ADD mix.lock mix.lock
ADD config/config.exs config/
ADD config/runtime.exs config/
ADD config/prod.exs config/

RUN mix do deps.get --only prod, deps.compile

ADD . .

RUN mix do compile, release

# Second stage: copies the files from the builder stage
FROM alpine:3.17.0

RUN apk add --update libssl1.1 ncurses-libs bash dumb-init libstdc++ libgcc \
    && rm -rf /var/cache/apk

# Set environment
ENV MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /root/

COPY --from=builder /root/_build/prod/rel /root/rel

# Ensure SSL support is enabled
RUN /root/rel/delta/bin/delta eval ":crypto.supports()"

HEALTHCHECK CMD ["/root/rel/delta/bin/delta", "rpc", "1 + 1"]
CMD ["/usr/bin/dumb-init", "/root/rel/delta/bin/delta", "start"]
