# d2gs

Docker setup for a complete **Diablo II closed realm** (Battle.net-style, characters stored on the server):

- **D2GS** 1.13d game server (with 1.14d `Patch_D2.mpq`), running under Wine 9 on Ubuntu 24.04
- **PvPGN** 1.99.8 (`bnetd`, `d2cs`, `d2dbs`), built from [espenmjos/pvpgn](https://github.com/espenmjos/pvpgn)

One `docker compose up` starts the whole realm. Players connect with a Diablo II / LoD **1.14d** client.

## Quick start

```sh
git clone https://github.com/espenmjos/d2gs.git
cd d2gs
cp .env.example .env          # set PUBLIC_IP (see below)
docker compose up -d --build
docker compose logs -f d2gs   # wait for "Game Server Activated by D2CS"
```

`PUBLIC_IP` is the address players use to reach this machine:

| Who plays                     | Set                                                                   |
|-------------------------------|-----------------------------------------------------------------------|
| Only people on your LAN       | `PUBLIC_IP` = the machine's LAN IP, e.g. `192.168.1.10`                |
| People on the internet        | `PUBLIC_IP` = your public IP, and forward ports 6112, 6113 and 4000 TCP (+ 6112 UDP) in your router |
| Both                          | Public IP as above, plus `LAN_IP` and `LAN_NETWORK` so LAN players get the local address |

Then point the game client at the server, e.g. with the
[PvPGN gateway installer](https://github.com/pvpgn/battle.net-gateway-installer) or by adding `PUBLIC_IP` to the
Battle.net gateway list in the registry.

The first build downloads about 1 GB of game files and takes a few minutes. See [Game files](#game-files) to keep a
local copy.

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
3. When the player creates/joins a game, d2cs tells the client which **D2GS** to connect to.
4. D2GS loads and saves characters through **d2dbs**.

In steps 2 and 3 PvPGN sends an IP address to the client. Inside Docker those are private container addresses the
client can't reach, so the stack uses PvPGN's **address translation** (`address_translation.conf`) to replace them
with `PUBLIC_IP` (or `LAN_IP` for clients in `LAN_NETWORK`). That file, `realm.conf` and the realm-related keys in
`d2cs.conf`/`d2dbs.conf` are written from environment variables on every start. The containers have fixed IPs so
these addresses never change.

## Configuration (`.env`)

| Variable              | Default                 | Description |
|-----------------------|-------------------------|-------------|
| `PUBLIC_IP`           | *(required)*            | Address players use to reach the server |
| `LAN_IP`              |                         | Address LAN players should use instead (optional) |
| `LAN_NETWORK`         |                         | LAN in CIDR form, e.g. `192.168.1.0/24` (with `LAN_IP`) |
| `REALM_NAME`          | `D2CS`                  | Realm name shown in the client |
| `REALM_DESCRIPTION`   | `PvPGN Closed Realm`    | Realm description |
| `MOTD`                | `Welcome to Diablo II!` | Message shown when joining a game |
| `MAX_GAMES`           | `50`                    | Max concurrent games |
| `D2GS_PASSWORD`       |                         | Shared secret between d2cs and D2GS |
| `PVPGN_BUILD_CONTEXT` | GitHub repo             | Build PvPGN from a local checkout, e.g. `../pvpgn` |

### PvPGN configuration and data

PvPGN's config lives in the `pvpgn-etc` volume and accounts, characters and ladders in `pvpgn-var`. Edit config
files with:

```sh
docker compose run --rm --entrypoint bash bnetd    # files are in /usr/local/etc/pvpgn
docker compose restart
```

Back up player data:

```sh
docker run --rm -v d2gs_pvpgn-var:/data -v "$PWD":/backup ubuntu tar czf /backup/pvpgn-var.tgz -C /data .
```

### D2GS configuration

D2GS has more environment variables (`MAX_GAME_LIFE`, `MAX_PREFER_USERS`, `ADMIN_PORT`, `ADMIN_PASSWORD_HASH`, …) —
see [`docker/entrypoint.sh`](docker/entrypoint.sh). To change game rules or Warden settings, mount a directory at
`/config` in the `d2gs` service containing your own `d2server.ini` or `d2warden.ini` (or a full `d2gs.reg`):

```sh
mkdir config
docker compose run --rm --entrypoint cat d2gs d2server.ini > config/d2server.ini
# edit, then add "- ./config:/config:ro" under volumes for d2gs in docker-compose.yml
```

### Admin console

D2GS has a telnet admin console, published on `127.0.0.1:8888` only (default password `abcd123`):

```sh
telnet 127.0.0.1 8888
```

## Game files

D2GS needs the Diablo II game files (~1 GB: MPQ archives, 1.13d DLLs and the 1.14d patch). The build uses whatever
is in `./gamefiles/` and only downloads what's missing, from [cdn.pvpgn.pro](http://cdn.pvpgn.pro/). Everything is
checked against [`scripts/gamefiles.md5`](scripts/gamefiles.md5).

Download once and reuse for every build:

```sh
scripts/fetch-gamefiles.sh        # fills ./gamefiles
```

You can also copy the MPQ files from your own Diablo II installation into `./gamefiles/`.

## Running only D2GS

If PvPGN already runs elsewhere, use [`examples/d2gs-only.compose.yml`](examples/d2gs-only.compose.yml). It uses
host networking so D2GS reports the host's own IP; set `D2CS_IP` in `.env` and add the D2GS host IP to
`gameservlist` in both `d2cs.conf` and `d2dbs.conf`.

```sh
docker compose -f examples/d2gs-only.compose.yml --env-file .env up -d --build
```

## Troubleshooting

- **Realm shows up but you can't log in to it, or you can't create/join games:** `PUBLIC_IP` is wrong, or ports
  6113/4000 aren't reachable. Check `docker compose logs d2cs` for `trans_load: Adding Host -> 172.30.0.20:4000,
  Output -> <your ip>:4000`.
- **D2GS doesn't connect:** `docker compose logs d2gs` should show `Game Server Activated by D2CS`. If not, check
  that `D2GS_PASSWORD` hasn't been set by hand differently in `d2cs.conf`.
- **Verbose Wine output:** set `WINEDEBUG=` (empty) in the `d2gs` environment.

## Background: Wine and the old `sock.c` patch

D2GS uses Windows' event-based sockets (`WSAEventSelect`). Windows reports "socket is writable" (`FD_WRITE`) only
once after connecting, and again only after a send would have blocked. Old Wine versions reported it every time the
socket was writable, flooding D2GS with events. Older D2GS-on-Wine guides therefore compiled Wine 2.0 with
[HarpyWar's `sock.c` patch](https://gist.github.com/HarpyWar/cd3676fa4916ea163c50).

Wine 7.0 rewrote its socket code to report each event only once until it is re-enabled, matching Windows. This image
uses the stock Wine 9 package from Ubuntu 24.04 without any patch. Measured idle CPU usage is the same as with the
patched Wine 2.0.1 (~5 % of one core), and builds take minutes instead of half an hour.

## References

- [D2GS installation guide (pvpgn.pro)](https://pvpgn.pro/d2gs_installation.html)
- [Diablo II files CDN](http://cdn.pvpgn.pro/)
- [PvPGN server](https://github.com/pvpgn/pvpgn-server)
- [PvPGN Magic Builder](https://github.com/pvpgn/pvpgn-magic-builder) (source of the D2GS binaries)
- [HarpyWar: D2GS under Wine](https://harpywar.com/?a=articles&b=2&c=2&d=21&lang=en)
- [TurBoss: D2GS under Wine](https://gist.github.com/TurBoss/3624782dd3d50b035e117f232063a999)
