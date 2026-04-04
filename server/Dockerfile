FROM golang:1.26.1-alpine3.23 AS builder

RUN apk update && apk upgrade
RUN apk add --no-cache gcc musl-dev git build-base pkgconfig

ENV GOOS=linux

WORKDIR /etc/ente/

COPY go.mod .
COPY go.sum .
RUN go mod download

COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
  go build -o museum cmd/museum/main.go

FROM alpine:3.23

RUN apk update && apk upgrade
COPY --from=builder /etc/ente/museum .
COPY configurations configurations
COPY migrations migrations
COPY mail-templates mail-templates
COPY web-templates web-templates

ARG GIT_COMMIT
ENV GIT_COMMIT=$GIT_COMMIT

CMD ["./museum"]
