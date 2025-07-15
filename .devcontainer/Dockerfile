FROM elixir:1.18

# Build Args
ARG NODE_VERSION=22.14.0

# Dependencies
RUN apt update \
  && apt upgrade -y \
  && apt install -y bash curl git build-essential inotify-tools libwxgtk-gl3.2-1 unzip

# NodeJS
ENV NVM_DIR=/opt/nvm
RUN mkdir -p ${NVM_DIR} \
  && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash \
  && . $NVM_DIR/nvm.sh \
  && nvm install ${NODE_VERSION} \
  && nvm alias default ${NODE_VERSION} \
  && nvm use default \
  && npm install -g yarn \
  && npm install -g @anthropic-ai/claude-code 


ENV NODE_PATH=$NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Install Hex and Rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# App Directory
ENV APP_HOME=/app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
