# syntax = docker/dockerfile:1

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t my-app .
# docker run -d -p 80:80 -p 443:443 --name my-app -e RAILS_MASTER_KEY=<value from config/master.key> my-app

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
FROM docker.io/library/ruby:3.2.2 AS base
ARG SECRET_KEY_BASE
ARG POSTGRES_URL
# Set a default value for SECRET_KEY_BASE for precompilation (overridable at build-time)
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE:-dummy_master_key}
ENV POSTGRES_URL=${POSTGRES_URL}
ENV RAILS_ENV=${RAILS_ENV:-production}

# Rails app lives here
WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    vim \
    redis-tools \
    curl \
    libjemalloc2 \
    postgresql-client \
    python3 \
    python3-dev \
    libpython3.11-dev \
    python3-pip \
    python3-venv && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install numpy optuna xgboost wandb

ENV PATH="/opt/venv/bin:$PATH"

ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    PYCALL_PYTHON=/usr/bin/python3

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE=$SECRET_KEY_BASE POSTGRES_URL=$POSTGRES_URL ./bin/rails assets:precompile

# Final stage for app image
FROM base AS app

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /app /app

# Entrypoint prepares the database.
ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]