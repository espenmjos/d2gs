#
# Diablo II Closed Game Server (D2GS) running under a patched Wine.
#
# Stages:
#   wine   - compiles Wine 2.0.1 with HarpyWar's sock.c patch (slow, cached)
#   files  - fetches D2GS binaries and Diablo II game files
#   final  - slim runtime image

ARG UBUNTU_VERSION=16.04

############################################################
# Stage 1: build patched Wine
############################################################
FROM ubuntu:${UBUNTU_VERSION} AS wine

ARG WINE_VERSION=2.0.1
ARG SOCK_PATCH_URL=https://gist.githubusercontent.com/HarpyWar/cd3676fa4916ea163c50/raw/50fbbff9a310d98496f458124fac14bda2e16cf0/sock.c

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y \
      ca-certificates wget xz-utils make flex bison \
      gcc-multilib g++-multilib \
      lib32z1 lib32ncurses5 \
      libfreetype6-dev:i386 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN wget -q https://dl.winehq.org/wine/source/2.0/wine-${WINE_VERSION}.tar.xz \
 && tar xf wine-${WINE_VERSION}.tar.xz \
 && mv wine-${WINE_VERSION} src \
 && wget -q -O src/server/sock.c "${SOCK_PATCH_URL}"

# 32-bit Wine, no X11 - D2GS is a headless console application.
WORKDIR /build/out
RUN ../src/configure --prefix=/opt/wine --without-x \
 && make -j"$(nproc)" \
 && make install \
 && rm -rf /opt/wine/include

############################################################
# Stage 2: D2GS + Diablo II game files
############################################################
FROM ubuntu:${UBUNTU_VERSION} AS files

ARG MAGIC_BUILDER_VERSION=2.29
ARG CDN=http://cdn.pvpgn.pro/diablo2

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates wget \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /d2gs

# D2GS 1.13d server binaries from PvPGN Magic Builder
RUN wget -q -O- https://github.com/pvpgn/pvpgn-magic-builder/archive/v${MAGIC_BUILDER_VERSION}.tar.gz \
  | tar xz --strip-components=5 pvpgn-magic-builder-${MAGIC_BUILDER_VERSION}/module/include/d2gs/1.13d \
 && rm -f d2gs.reg d2gs_install.bat d2gs_uninstall.bat

# Game libraries (1.13d) + 1.14d patch, and the big MPQ archives (~1 GB).
# Kept in separate layers so a failed download doesn't refetch everything.
RUN for f in D2Client.dll D2CMP.dll D2Common.dll D2Game.dll D2gfx.dll D2Lang.dll \
             D2MCPClient.dll D2Net.dll D2sound.dll D2Win.dll Fog.dll Storm.dll; do \
      wget -q "${CDN}/1.13d/$f" || exit 1; \
    done \
 && wget -q "${CDN}/1.14d/Patch_D2.mpq" \
 && wget -q "${CDN}/1.14d/ijl11.dll"
RUN for f in d2data.mpq d2exp.mpq d2sfx.mpq d2speech.mpq; do \
      wget -q "${CDN}/$f" || exit 1; \
    done

############################################################
# Stage 3: runtime
############################################################
FROM ubuntu:${UBUNTU_VERSION}

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      libc6:i386 libfreetype6:i386 zlib1g:i386 libncurses5:i386 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 1000 d2gs

COPY --from=wine /opt/wine /opt/wine
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

ENV PATH=/opt/wine/bin:$PATH \
    WINEPREFIX=/home/d2gs/.wine \
    WINEARCH=win32 \
    WINEDEBUG=-all

USER d2gs
RUN wineboot --init && wineserver --wait

COPY --from=files --chown=d2gs:d2gs /d2gs ${WINEPREFIX}/drive_c/d2gs

WORKDIR ${WINEPREFIX}/drive_c/d2gs

# 4000/tcp: game traffic, 8888/tcp: telnet admin console
EXPOSE 4000 8888

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
