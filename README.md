# WORK ONGOING, CANNOT GUARANTY STABILITY
# d2gs
Ubuntu Docker image of Diablo 2 Game Server v1.13d

Intended to use as a private Diablo 2 game server in combination with pvpgn. See https://pvpgn.pro/d2gs_installation.html for overview. 
Tested together with a docker image of pvpgn on the same server. I will also upload this soon.

# Build 
Warning! Takes a long time to build (~30min for installing wine + download time of 1GB data + ~2min finalizing) and downloads over 1GB of data files. For continuous build testing please map needed Diablo 2 files from a local folder.  
Clone repository:
```
git clone https://github.com/espenmjos/d2gs.git
```
Edit conf/d2gs.reg 
Set "D2CSIP" and "D2DBSIP" to server IP of docker host

Build the image: 
```
docker build -t d2gs:1.0.0 .
```

Run container:
```
docker run -d --name d2gs --net=host d2gs:1.0.0
```
Have currently only tested with host network. 

# Can it run on newer versions
I have tried ubuntu image 18.04 without any luck, but did'nt use any time to figure it out. 
I also tried wine 5.0.2, but the sock.c change cannot be copied and used directly so I gave up. 

# Additional documentation

## Diablo 2 files repository
http://cdn.pvpgn.pro/

## PvPGN Magic Builder
https://github.com/pvpgn/pvpgn-magic-builder

## Harpywar Diablo 2 Game Server 
https://harpywar.com/?a=articles&b=2&c=2&d=21&lang=en

## Pvpgn Battlenet server
https://github.com/pvpgn/pvpgn-server

## TurBoss D2GS under Wine
https://gist.github.com/TurBoss/3624782dd3d50b035e117f232063a999

## D2GS Installation Guide
https://pvpgn.pro/d2gs_installation.html

## PvPGN Server Docker wwmoraes
https://github.com/wwmoraes/pvpgn-server-docker

## Diablo 2 Battlenet Tools
https://github.com/fw42/diablo2
