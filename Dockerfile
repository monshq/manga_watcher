FROM --platform=linux/amd64 elixir:1.13-otp-23-slim AS build

ENV ENV prod
ENV MIX_ENV prod

# RUN apt-get update && apt-get install -y git unzip curl build-essential autoconf libssh-dev libncurses5-dev
# ENV ASDF_DIR=/opt/asdf
# RUN git clone https://github.com/asdf-vm/asdf.git $ASDF_DIR
# ENV PATH=$ASDF_DIR/shims:$ASDF_DIR/bin:$PATH
# ENV ASDF_DATA_DIR=$ASDF_DIR
#
# RUN asdf plugin add alias
#
# RUN asdf plugin add erlang
# RUN asdf plugin add elixir

WORKDIR /app

# ADD .tool-versions .
# RUN asdf install

RUN mix do local.hex --force, local.rebar --force
ADD mix.exs mix.lock .
RUN mix deps.get --only prod
RUN mix deps.compile

ADD assets config lib priv rel .
RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM scratch AS export
COPY --from=build /app/_build/prod/rel/manga_watcher /
