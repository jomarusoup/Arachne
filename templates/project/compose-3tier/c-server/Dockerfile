# syntax=docker/dockerfile:1
################################################################################
# FILE NAME   : Dockerfile
# DESCRIPTION : C 서버 빌드·테스트·실행 이미지. 소스는 compose 의 추가 컨텍스트 csrc
#               (c-system/src)로 받는다. 호스트의 빌드 산출물이 섞여 와도 make clean 으로
#               지우고 Linux 에서 다시 빌드한다.
#                 target test    — 모듈 단위 테스트를 Linux 에서 실행 (기본 c-build 서비스)
#                 target runtime — src/<APP_DIR> 의 서버 바이너리만 담은 실행 이미지
#               빌드 도구는 실행 이미지에 남기지 않는다. 두 이미지 모두 non-root 로 돈다.
#               규약: rules/docker/*.md, skills/docker-patterns/SKILL.md
################################################################################

ARG DEBIAN_TAG=12.11-slim

#-------------------------------------------------------------------------------
# build — 컴파일러와 소스. 배포 빌드도 심볼 일치를 위해 -g -fno-omit-frame-pointer 를 쓴다
#-------------------------------------------------------------------------------
FROM debian:${DEBIAN_TAG} AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libc6-dev make \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
WORKDIR /work
COPY --from=csrc --chown=app:app . ./src/
USER app

#-------------------------------------------------------------------------------
# test — 모듈 테스트를 하나씩 돈다. 첫 실패에서 멈춘다
#-------------------------------------------------------------------------------
FROM build AS test
ENV C_MODULES="log shm pipeline contract"
CMD ["/bin/sh", "-c", "set -e; for mod in ${C_MODULES}; do echo \"[c-build] make -C src/${mod} test\"; make -C \"src/${mod}\" clean test; done"]

#-------------------------------------------------------------------------------
# server-build — 서버 진입점을 빌드한다. src/<APP_DIR>/Makefile 의 all 이 <APP_NAME> 을 만든다
#-------------------------------------------------------------------------------
FROM build AS server-build
ARG APP_DIR=server
ARG APP_NAME=appd
RUN make -C "src/${APP_DIR}" clean all \
    && mkdir -p out \
    && cp "src/${APP_DIR}/${APP_NAME}" out/server

#-------------------------------------------------------------------------------
# runtime — 바이너리만. 쓰기 가능한 곳은 compose 의 tmpfs·볼륨으로 따로 준다
#-------------------------------------------------------------------------------
FROM debian:${DEBIAN_TAG} AS runtime
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
COPY --from=server-build --chown=root:root --chmod=0755 /work/out/server /app/bin/server
USER 10001:10001
ENTRYPOINT ["/app/bin/server"]
