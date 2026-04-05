# Docs - https://github.com/ente-io/ente/blob/main/web/docs/docker.md
ARG NODE_VERSION=24.14.1
ARG NGINX_VERSION=1.29.7

FROM node:${NODE_VERSION} AS builder

# Install Rust for building ente-wasm
RUN apt-get update && apt-get upgrade -y && apt-get install -y curl build-essential
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --target wasm32-unknown-unknown
ENV PATH="/root/.cargo/bin:${PATH}"

ENV NEXT_PUBLIC_ENTE_ENDPOINT=ENTE_API_ORIGIN_PLACEHOLDER
ENV NEXT_PUBLIC_ENTE_ALBUMS_ENDPOINT=ENTE_ALBUMS_ORIGIN_PLACEHOLDER
ENV NEXT_PUBLIC_ENTE_PHOTOS_ENDPOINT=ENTE_PHOTOS_ORIGIN_PLACEHOLDER

RUN corepack enable && corepack prepare yarn@1.22.22 --activate

# `yarn install` is flaky on the GitHub arm64 runners otherwise.
RUN yarn config set network-timeout 900000 -g

WORKDIR /build

# workspace root files
COPY web/package.json web/package.json
COPY web/yarn.lock web/yarn.lock
COPY web/turbo.json web/turbo.json

# app dirs
COPY web/apps/accounts/package.json web/apps/accounts/package.json
COPY web/apps/albums/package.json web/apps/albums/package.json
COPY web/apps/auth/package.json web/apps/auth/package.json
COPY web/apps/cast/package.json web/apps/cast/package.json
COPY web/apps/embed/package.json web/apps/embed/package.json
COPY web/apps/memories/package.json web/apps/memories/package.json
COPY web/apps/share/package.json web/apps/share/package.json
COPY web/apps/paste/package.json web/apps/paste/package.json
COPY web/apps/photos/package.json web/apps/photos/package.json

# package dirs
COPY web/packages/accounts/package.json web/packages/accounts/package.json
COPY web/packages/accounts-rs/package.json web/packages/accounts-rs/package.json
COPY web/packages/base/package.json web/packages/base/package.json
COPY web/packages/build-config/package.json web/packages/build-config/package.json
COPY web/packages/gallery/package.json web/packages/gallery/package.json
COPY web/packages/media/package.json web/packages/media/package.json
COPY web/packages/new/package.json web/packages/new/package.json
COPY web/packages/utils/package.json web/packages/utils/package.json
COPY web/packages/wasm/ web/packages/wasm
COPY rust/.cargo/ ./rust/.cargo/

ENV YARN_CACHE_FOLDER=/opt/yarn

RUN --mount=type=cache,id=yarn,target=/opt/yarn \
    cd web && yarn install --frozen-lockfile

# build and cache wasm first
COPY rust/core/ ./rust/core
COPY web/packages/build-config/ ./web/packages/build-config
COPY web/packages/wasm/ ./web/packages/wasm
WORKDIR /build/web
RUN --mount=type=cache,id=cargo-registry,target=/root/.cargo/registry \
    --mount=type=cache,id=cargo-git,target=/root/.cargo/git \
    --mount=type=cache,id=wasm-target,target=/build/web/packages/wasm/target \
    --mount=type=cache,id=wasm-pack,target=/root/.cache/.wasm-pack \
    --mount=type=cache,id=wasm-turbo,target=packages/wasm/.turbo \
    yarn build:wasm

# add remaining packages (skip wasm — already built above) and all apps
COPY web/packages/accounts/ packages/accounts/
COPY web/packages/accounts-rs/ packages/accounts-rs/
COPY web/packages/base/ packages/base/
COPY web/packages/gallery/ packages/gallery/
COPY web/packages/media/ packages/media/
COPY web/packages/new/ packages/new/
COPY web/packages/utils/ packages/utils/
COPY web/apps/ apps/

# build all apps in parallel with Turborepo
# cargo/wasm-pack mounts needed because ente-wasm#build (cache:false) re-runs
# as a dependency of apps that depend on it — fast from cache (~1s)
RUN --mount=type=cache,id=turbo,target=.turbo \
    --mount=type=cache,id=cargo-registry,target=/root/.cargo/registry \
    --mount=type=cache,id=cargo-git,target=/root/.cargo/git \
    --mount=type=cache,id=wasm-target,target=packages/wasm/target \
    --mount=type=cache,id=wasm-pack,target=/root/.cache/.wasm-pack \
    yarn turbo build build:post \
    --filter=accounts --filter=albums --filter=auth --filter=cast \
    --filter=embed --filter=memories --filter=paste --filter=photos \
    --filter=share

# https://hub.docker.com/hardened-images/catalog/dhi/nginx
FROM nginx:${NGINX_VERSION}

WORKDIR /out

COPY --from=builder --chown=nginx /build/web/apps/accounts/out /out/accounts
COPY --from=builder --chown=nginx /build/web/apps/albums/out /out/albums
COPY --from=builder --chown=nginx /build/web/apps/auth/out /out/auth
COPY --from=builder --chown=nginx /build/web/apps/cast/out /out/cast
COPY --from=builder --chown=nginx /build/web/apps/embed/out /out/embed
COPY --from=builder --chown=nginx /build/web/apps/memories/out /out/memories
COPY --from=builder --chown=nginx /build/web/apps/paste/out /out/paste
COPY --from=builder --chown=nginx /build/web/apps/photos/out /out/photos
COPY --from=builder --chown=nginx /build/web/apps/share/out /out/share

COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 3000; root /out/photos;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3001; root /out/accounts;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3002; root /out/albums;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3003; root /out/auth;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3004; root /out/cast;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3005; root /out/share;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3006; root /out/embed;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3007; root /out/memories;
    location / { try_files \$uri \$uri.html /index.html; }
}
server {
    listen 3008; root /out/paste;
    location / { try_files \$uri \$uri.html /index.html; }
}
EOF

EXPOSE 3000
EXPOSE 3001
EXPOSE 3002
EXPOSE 3003
EXPOSE 3004
EXPOSE 3005
EXPOSE 3006
EXPOSE 3007
EXPOSE 3008

ENV ENTE_API_ORIGIN=http://localhost:8080
ENV ENTE_ALBUMS_ORIGIN=http://localhost:3002
ENV ENTE_PHOTOS_ORIGIN=http://localhost:3000

COPY <<EOF /docker-entrypoint.d/90-replace-ente-env.sh
find /out -name '*.js' |
    xargs sed -i'' "s#ENTE_API_ORIGIN_PLACEHOLDER#\$ENTE_API_ORIGIN#g"
find /out/photos -name '*.js' |
    xargs sed -i'' "s#ENTE_ALBUMS_ORIGIN_PLACEHOLDER#\$ENTE_ALBUMS_ORIGIN#g"
find /out/albums -name '*.js' |
    xargs sed -i'' "s#ENTE_ALBUMS_ORIGIN_PLACEHOLDER#\$ENTE_ALBUMS_ORIGIN#g"
find /out/photos -name '*.js' |
    xargs sed -i'' "s#ENTE_PHOTOS_ORIGIN_PLACEHOLDER#\$ENTE_PHOTOS_ORIGIN#g"
find /out/albums -name '*.js' |
    xargs sed -i'' "s#ENTE_PHOTOS_ORIGIN_PLACEHOLDER#\$ENTE_PHOTOS_ORIGIN#g"
EOF

RUN chmod +x /docker-entrypoint.d/90-replace-ente-env.sh
