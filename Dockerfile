FROM elixir:1.20-otp-29 AS build

ENV ENV=prod \
    MIX_ENV=prod

WORKDIR /app

RUN mix do local.hex --force, local.rebar --force
ADD mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

ADD assets assets
ADD config config
ADD lib lib
ADD priv priv
ADD rel rel

RUN mix assets.setup
RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM elixir:1.20-otp-29

ENV LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PORT=80

WORKDIR /app

RUN useradd --create-home --shell /bin/bash app

COPY --from=build --chown=app:app /app/_build/prod/rel/manga_watcher /app

USER app

EXPOSE 80

CMD ["/app/bin/manga_watcher", "start"]
