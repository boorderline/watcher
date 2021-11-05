FROM alpine:3.14 AS build

RUN apk add --no-cache build-base \
    libressl-dev yaml-static zlib-static \
    crystal shards

WORKDIR /opt/app

COPY ./src ./src
COPY shard.* .

RUN shards build --release --static --no-debug

FROM alpine:3.14

RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing helm

COPY --from=build /opt/app/bin/watcher /usr/local/bin

VOLUME [ "/opt/watcher/config" ]

RUN adduser -D watcher
USER watcher

ENTRYPOINT [ "watcher", "-d", "/opt/watcher/config" ]