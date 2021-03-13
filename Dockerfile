FROM ubuntu:16.04

RUN dpkg --add-architecture i386
RUN apt-get update && apt-get install -y \
  make \
  wget \
  flex \
  bison \
  xz-utils \
  lib32z1 \
  lib32ncurses5 \
  gcc-multilib \
  g++-multilib \
  xserver-xorg-dev:i386 \
  libfreetype6-dev:i386

RUN cd /home && wget http://dl.winehq.org/wine/source/2.0/wine-2.0.1.tar.xz && tar xf wine-2.0.1.tar.xz && rm wine-2.0.1.tar.xz && wget https://gist.githubusercontent.com/HarpyWar/cd3676fa4916ea163c50/raw/50fbbff9a310d98496f458124fac14bda2e16cf0/sock.c && mv sock.c wine-2.0.1/server && mv wine-2.0.1 wine-source && mkdir wine-dirs && mv wine-source wine-dirs && cd wine-dirs && mkdir wine-build && cd wine-build
WORKDIR "/home/wine-dirs/wine-build"
RUN ../wine-source/configure --without-x
RUN make -j 10 && make install -j 10

RUN cd /home && wget https://github.com/pvpgn/pvpgn-magic-builder/archive/v2.29.tar.gz && tar xf v2.29.tar.gz && mv pvpgn-magic-builder-2.29/module/include/d2gs/1.13d d2gs
COPY conf/d2gs.reg /home/d2gs/
COPY conf/start.sh /home/d2gs/
RUN winecfg
RUN cd /home/d2gs && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2Client.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2CMP.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2Common.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2Game.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2gfx.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2Lang.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2MCPClient.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2Net.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2sound.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/D2Win.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/Fog.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.13d/Storm.dll && \
  #wget http://cdn.pvpgn.pro/diablo2/1.13d/Patch_D2.mpq && \   
  #wget http://cdn.pvpgn.pro/diablo2/ijl11.dll && \
  wget http://cdn.pvpgn.pro/diablo2/1.14d/Patch_D2.mpq \
  wget http://cdn.pvpgn.pro/diablo2/1.14d/ijl11.dll
  wget http://cdn.pvpgn.pro/diablo2/d2speech.mpq && \
  wget http://cdn.pvpgn.pro/diablo2/d2data.mpq && \
  wget http://cdn.pvpgn.pro/diablo2/d2sfx.mpq && \
  wget http://cdn.pvpgn.pro/diablo2/d2exp.mpq && \
  mv /home/d2gs /root/.wine/drive_c/d2gs 

WORKDIR "/root/.wine/drive_c/d2gs"
RUN ["chmod", "+x", "./start.sh"]

ENTRYPOINT ["./start.sh"]
