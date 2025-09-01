FROM --platform=linux/amd64 elixir:1.18-otp-28 AS build

ENV ENV=prod
ENV MIX_ENV=prod

WORKDIR /app

RUN mix do local.hex --force, local.rebar --force
ADD mix.exs mix.lock .
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

FROM scratch AS export
COPY --from=build /app/_build/prod/rel/manga_watcher /
ADD script script
ADD Procfile .
