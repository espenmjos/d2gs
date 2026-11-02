<h1 align="center">d2gs</h1>

<p align="center">
  <b>A self-hosted Diablo II closed realm in one <code>docker compose up</code>.</b><br>
  PvPGN + D2GS on Ubuntu 24.04 and stock Wine 9, with server-side characters, ladders and LAN/internet support.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/espenmjos/d2gs"></a>
  <img alt="Diablo II 1.14d" src="https://img.shields.io/badge/Diablo%20II-1.14d-8b0000">
  <img alt="PvPGN 1.99.8" src="https://img.shields.io/badge/PvPGN-1.99.8-blue">
  <img alt="Wine 9" src="https://img.shields.io/badge/Wine-9-722f37">
  <img alt="Docker Compose" src="https://img.shields.io/badge/docker-compose-2496ed?logo=docker&logoColor=white">
</p>

---

**d2gs** runs a complete Battle.net-style **closed realm** for Diablo II. Characters are stored on the server, just
like on the official realms. You don't need a Windows server, have to build Wine by hand or edit IP addresses in five
config files.

| Component | Version | Role |
|-----------|---------|------|
| **D2GS** | 1.13d with the 1.14d `Patch_D2.mpq` | Game server (runs under Wine) |
| **bnetd** | PvPGN 1.99.8 | Login, chat and channels |
| **d2cs** | PvPGN 1.99.8 | Character and realm server |
| **d2dbs** | PvPGN 1.99.8 | Character and ladder database |

PvPGN is built from [espenmjos/pvpgn](https://github.com/espenmjos/pvpgn).

## Features

- **One command:** all four services start and connect to each other automatically.
- **Configured with environment variables:** realm name, MOTD, IP addresses and limits go in `.env`. Nothing is
  hard-coded in config files.
- **Correct IP addresses:** PvPGN's address translation gives players the public IP, or the LAN IP for players
  on your own network.
- **Stock Wine 9:** the old patched Wine 2.0 build is no longer needed
  ([background](#background-wine-and-the-old-sockc-patch)).
- **Game files are verified and cached:** they are downloaded once, checked with MD5 and reused for every build.
- **Data survives restarts:** accounts, characters and ladders are kept in Docker volumes.

## Contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Connecting with a game client](#connecting-with-a-game-client)
- [How it works](#how-it-works)
- [Configuration](#configuration)
- [Operations](#operations)
- [Game files](#game-files)
- [Running only D2GS](#running-only-d2gs)
- [Troubleshooting](#troubleshooting)
- [Project status](#project-status)
- [Background: Wine and the old `sock.c` patch](#background-wine-and-the-old-sockc-patch)
- [Credits and references](#credits-and-references)
- [License and legal](#license-and-legal)

## Requirements

- A Linux host on **x86-64** with [Docker Engine](https://docs.docker.com/engine/install/) and the
  [Compose plugin](https://docs.docker.com/compose/install/linux/) (`docker compose`, v2)
- About **6 GB of free disk**: the D2GS image is about 4 GB, plus 1 GB if you keep the game files locally
- About **512 MB of RAM**. The whole realm uses about 200 MB, and about 5 % of one CPU core when idle.
- A **Diablo II 1.14d** client for each player

## Quick start

```sh
git clone https://github.com/espenmjos/d2gs.git
cd d2gs
cp .env.example .env          # set PUBLIC_IP (see below)
docker compose up -d --build
docker compose logs -f d2gs   # wait for "Game Server Activated by D2CS"
```

`PUBLIC_IP` is the address players use to reach this machine:

| Who plays | What to set |
|-----------|-------------|
| Only people on your LAN | `PUBLIC_IP` = the machine's LAN IP, e.g. `192.168.1.10` |
| People on the internet | `PUBLIC_IP` = your public IP. Forward the [ports](#ports) in your router. |
| Both | Public IP as above, plus `LAN_IP` and `LAN_NETWORK` so LAN players get the local address |

The first build downloads about 1 GB of game files and takes a few minutes. Run
[`scripts/fetch-gamefiles.sh`](#game-files) first to keep a local copy for later builds.

### Ports

| Port | Protocol | Service | Expose to players |
|------|----------|---------|-------------------|
| 6112 | TCP + UDP | bnetd: login and chat | Yes |
| 6113 | TCP | d2cs: character and realm server | Yes |
| 4000 | TCP | D2GS: game traffic | Yes |
| 8888 | TCP | D2GS admin console (telnet) | **No**. It only listens on `127.0.0.1`. |

## Connecting with a game client

1. Install Diablo II (and Lord of Destruction, if you have it) and patch it to **1.14d**.
2. Add the server as a Battle.net gateway. The easiest way is the
   [PvPGN gateway installer](https://github.com/pvpgn/battle.net-gateway-installer). You can also add `PUBLIC_IP`
   to the `Diablo II Battle.net gateways` value under `HKEY_CURRENT_USER\Software\Battle.net\Configuration` in the
   registry yourself.
3. Start the game and choose **Battle.net**. Create an account the first time you log in.
4. Create a character on the realm (`REALM_NAME`, `D2CS` by default) and create or join a game.

## How it works

```
                          host ports            private network 172.30.0.0/24
Diablo II client ──────►  6112  ──────────────►  bnetd   172.30.0.10
                 ──────►  6113  ──────────────►  d2cs    172.30.0.11 ◄──┐
                 ──────►  4000  ──────────────►  d2gs    172.30.0.20 ───┤
                                                 d2dbs   172.30.0.12 ◄──┘
```

1. The client logs in to **bnetd** and picks the realm.
2. bnetd tells the client where **d2cs** (the character server) is.
3. When the player creates or joins a game, d2cs tells the client which **D2GS** to connect to.
4. D2GS loads and saves characters through **d2dbs**.

In steps 2 and 3 PvPGN sends an IP address to the client. Inside Docker these would be private container addresses
that the client can't reach. The stack therefore uses PvPGN's **address translation** (`address_translation.conf`)
to replace them with `PUBLIC_IP`, or with `LAN_IP` for clients in `LAN_NETWORK`.

On every start, these files are written from environment variables:

- `address_translation.conf`
- `realm.conf`
- the realm settings in `d2cs.conf` and `d2dbs.conf`

The containers have fixed IP addresses, so the translated addresses never change.

## Configuration

### Environment variables (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `PUBLIC_IP` | *(required)* | Address players use to reach the server |
| `LAN_IP` | | Address LAN players should use instead (optional) |
| `LAN_NETWORK` | | Your LAN in CIDR form, e.g. `192.168.1.0/24` (used with `LAN_IP`) |
| `REALM_NAME` | `D2CS` | Realm name shown in the client |
| `REALM_DESCRIPTION` | `PvPGN Closed Realm` | Realm description |
| `MOTD` | `Welcome to Diablo II!` | Message shown when a player joins a game |
| `MAX_GAMES` | `50` | Maximum number of games at the same time |
| `D2GS_PASSWORD` | | Shared secret between d2cs and D2GS |
| `PVPGN_BUILD_CONTEXT` | GitHub repo | Build PvPGN from a local checkout instead, e.g. `../pvpgn` |

D2GS has more settings, such as `MAX_GAME_LIFE`, `MAX_PREFER_USERS`, `ADMIN_PORT` and `ADMIN_PASSWORD_HASH`. See
[`docker/entrypoint.sh`](docker/entrypoint.sh) for the full list and defaults. To use them, add them under
`environment:` for the `d2gs` service in `docker-compose.yml`.

### PvPGN configuration

PvPGN's config files are in the `pvpgn-etc` volume. To edit them:

```sh
docker compose run --rm --entrypoint bash bnetd    # the files are in /usr/local/etc/pvpgn
docker compose restart
```

### D2GS game rules and Warden

To change game rules or Warden settings, mount a directory at `/config` in the `d2gs` service. It can contain your
own `d2server.ini` or `d2warden.ini`, or a complete `d2gs.reg`:

```sh
mkdir config
docker compose run --rm --entrypoint cat d2gs d2server.ini > config/d2server.ini
# Edit the file, then add "- ./config:/config:ro" under volumes for d2gs in docker-compose.yml
```

## Operations

### Logs

```sh
docker compose logs -f            # all services
docker compose logs -f d2gs       # only the game server
```

### Admin console

D2GS has a telnet admin console. It only listens on `127.0.0.1:8888`, and the default password is `abcd123`:

```sh
telnet 127.0.0.1 8888
```

To change the password, make a hash with PvPGN's `bnpass` tool and set it as `ADMIN_PASSWORD_HASH` for `d2gs`:

```sh
docker compose exec bnetd bnpass    # enter the new password and copy the hash
```

### Backup and restore

Accounts, characters and ladders are in the `pvpgn-var` volume:

```sh
# Backup
docker run --rm -v d2gs_pvpgn-var:/data -v "$PWD":/backup ubuntu tar czf /backup/pvpgn-var.tgz -C /data .

# Restore (stop the realm first)
docker compose down
docker run --rm -v d2gs_pvpgn-var:/data -v "$PWD":/backup ubuntu tar xzf /backup/pvpgn-var.tgz -C /data
docker compose up -d
```

The volume names begin with the project name, which is the directory name `d2gs` by default.

### Updating

```sh
git pull
docker compose up -d --build
```

Data in the volumes is kept when you update.

## Game files

D2GS needs the Diablo II game files (about 1 GB): the MPQ archives, the 1.13d DLLs and the 1.14d patch. The build
uses the files in `./gamefiles/` and only downloads what's missing, from [cdn.pvpgn.pro](http://cdn.pvpgn.pro/).
All files are checked against [`scripts/gamefiles.md5`](scripts/gamefiles.md5).

To download the files once and reuse them for every build:

```sh
scripts/fetch-gamefiles.sh        # fills ./gamefiles
```

You can also copy the MPQ files from your own Diablo II installation into `./gamefiles/`.

## Running only D2GS

If PvPGN already runs somewhere else, use
[`examples/d2gs-only.compose.yml`](examples/d2gs-only.compose.yml). It uses host networking, so D2GS reports the
host's own IP address. Before you start it:

1. Set `D2CS_IP` in `.env`.
2. Add the D2GS host's IP to `gameservlist` in both `d2cs.conf` and `d2dbs.conf`.

```sh
docker compose -f examples/d2gs-only.compose.yml --env-file .env up -d --build
```

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| The realm shows up, but you can't log in to it or create/join games | `PUBLIC_IP` is wrong, or ports 6113 and 4000 can't be reached. `docker compose logs d2cs` should show `trans_load: Adding Host -> 172.30.0.20:4000, Output -> <your ip>:4000`. |
| D2GS doesn't connect to d2cs | `docker compose logs d2gs` should show `Game Server Activated by D2CS`. If it doesn't, check that `D2GS_PASSWORD` hasn't been set to something else by hand in `d2cs.conf`. |
| You can play on the LAN but not from the internet (or the other way round) | Set `PUBLIC_IP`, `LAN_IP` and `LAN_NETWORK` as described in [Quick start](#quick-start). Check the port forwarding in your router. |
| You need more output from Wine | Set `WINEDEBUG=` (empty) in the `d2gs` environment. |

## Project status

| Area | Status |
|------|--------|
| Classic Diablo II 1.14d client: login, character creation, games, saving | ✅ Tested end to end |
| Lord of Destruction | ⚠️ Not tested yet. It should work, but feedback is welcome. |
| Hosts other than x86-64 (ARM) | ❌ Not supported. D2GS is a 32-bit Windows program. |

Bug reports and pull requests are welcome.

## Background: Wine and the old `sock.c` patch

D2GS uses event-based Windows sockets (`WSAEventSelect`). Windows reports "socket is writable" (`FD_WRITE`) once
after connecting, and after that only when a send would have blocked. Old Wine versions reported it every time the
socket was writable, which flooded D2GS with events. Older guides for D2GS on Wine therefore compiled Wine 2.0 with
[HarpyWar's `sock.c` patch](https://gist.github.com/HarpyWar/cd3676fa4916ea163c50).

Wine 7.0 rewrote its socket code. Each event is now reported only once until it is re-enabled, which is how Windows
does it. This image uses the stock Wine 9 package from Ubuntu 24.04 without any patch. Idle CPU usage is the same as
with the patched Wine 2.0.1 (about 5 % of one core), and a build takes minutes instead of half an hour.

## Credits and references

- [PvPGN](https://github.com/pvpgn/pvpgn-server): the Battle.net server emulator
- [PvPGN Magic Builder](https://github.com/pvpgn/pvpgn-magic-builder): source of the D2GS binaries
- [D2GS installation guide (pvpgn.pro)](https://pvpgn.pro/d2gs_installation.html) and the
  [Diablo II files CDN](http://cdn.pvpgn.pro/)
- [HarpyWar: D2GS under Wine](https://harpywar.com/?a=articles&b=2&c=2&d=21&lang=en)
- [TurBoss: D2GS under Wine](https://gist.github.com/TurBoss/3624782dd3d50b035e117f232063a999)

## License and legal

The code in this repository (Dockerfile, scripts and compose files) is released under the [MIT License](LICENSE).

This project is not affiliated with or endorsed by Blizzard Entertainment. Diablo and Battle.net are trademarks of
Blizzard Entertainment, Inc. The game files are Blizzard's property and are not part of this repository. Only use
them if you own a legitimate copy of Diablo II. This project is for private servers and preservation, not for
commercial use.
