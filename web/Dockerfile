# Docs - https://github.com/ente-io/ente/blob/main/web/docs/docker.md

FROM node:24.14.1 AS builder

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

COPY web/package.json web/package.json
COPY web/yarn.lock web/yarn.lock
COPY web/apps/accounts/package.json web/apps/accounts/package.json
COPY web/apps/albums/package.json web/apps/albums/package.json
COPY web/apps/auth/package.json web/apps/auth/package.json
COPY web/apps/cast/package.json web/apps/cast/package.json
COPY web/apps/embed/package.json web/apps/embed/package.json
COPY web/apps/memories/package.json web/apps/memories/package.json
COPY web/apps/share/package.json web/apps/share/package.json
COPY web/apps/paste/package.json web/apps/paste/package.json
COPY web/apps/photos/package.json web/apps/photos/package.json

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
RUN yarn build:wasm

# add all packages before building the apps below
COPY web/packages/ packages

# build and cache each app individually so they only need to be rebuilt if their code changes
COPY web/apps/paste/ ./apps/paste
RUN yarn workspace paste next build --no-lint && yarn workspace paste build:post

COPY web/apps/share/ ./apps/share
RUN yarn workspace share next build && yarn workspace share build:post

COPY web/apps/cast/ ./apps/cast
RUN yarn workspace cast next build --no-lint

COPY web/apps/embed/ ./apps/embed
RUN yarn workspace embed next build --no-lint

COPY web/apps/memories/ ./apps/memories
RUN yarn workspace memories next build --no-lint && yarn workspace memories build:post

COPY web/apps/albums/ ./apps/albums
RUN yarn workspace albums next build --no-lint

COPY web/apps/auth/ ./apps/auth
RUN yarn workspace auth next build --no-lint

COPY web/apps/accounts/ ./apps/accounts
RUN yarn workspace accounts next build --no-lint

COPY web/apps/photos/ ./apps/photos
RUN yarn workspace photos next build --no-lint

# https://hub.docker.com/hardened-images/catalog/dhi/nginx
FROM dhi.io/nginx:1-debian13-dev

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

# run as non-root user by default
USER nginx
