#
# Diablo II Closed Game Server (D2GS) running under Wine.
#
# Game files are taken from ./gamefiles if present, otherwise downloaded
# (~1 GB). Run scripts/fetch-gamefiles.sh once to keep a local copy.

ARG UBUNTU_VERSION=24.04

############################################################
# Stage 1: D2GS + Diablo II game files
############################################################
FROM ubuntu:${UBUNTU_VERSION} AS files

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates wget \
 && rm -rf /var/lib/apt/lists/*

COPY scripts/ /scripts/
COPY gamefiles/ /d2gs/
RUN /scripts/fetch-gamefiles.sh /d2gs \
 && rm -f /d2gs/.gitkeep /d2gs/*.part

############################################################
# Stage 2: runtime
############################################################
FROM ubuntu:${UBUNTU_VERSION}

# Wine >= 7 reports socket events the way Windows does, so the old
# HarpyWar sock.c patch for Wine 2.0 is no longer needed.
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends wine wine32:i386 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home d2gs

ENV WINEPREFIX=/home/d2gs/.wine \
    WINEARCH=win32 \
    WINEDEBUG=-all

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

USER d2gs
RUN wineboot --init && wineserver --wait

COPY --from=files --chown=d2gs:d2gs /d2gs ${WINEPREFIX}/drive_c/d2gs
WORKDIR ${WINEPREFIX}/drive_c/d2gs

# 4000/tcp: game traffic, 8888/tcp: telnet admin console
EXPOSE 4000 8888

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
