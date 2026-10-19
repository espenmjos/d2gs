# d2gs

Docker image for the **Diablo II Closed Game Server (D2GS)**, running under a patched Wine on Ubuntu.

D2GS hosts the actual game sessions for a private Battle.net realm. It does nothing on its own: it needs a
[PvPGN](https://github.com/pvpgn/pvpgn-server) server running `bnetd`, `d2cs` and `d2dbs`. For a ready-made
PvPGN container, see [espenmjos/pvpgn](https://github.com/espenmjos/pvpgn).

```
Diablo II client ──► bnetd (6112) ──► d2cs (6113) ◄──── d2gs (this image, 4000)
                                       d2dbs (6114) ◄───┘
```

| Component       | Version                                    |
|-----------------|--------------------------------------------|
| D2GS            | 1.13d (from PvPGN Magic Builder 2.29)      |
| Game patch      | `Patch_D2.mpq` 1.14d                       |
| Wine            | 2.0.1 + [HarpyWar's `sock.c` patch](https://gist.github.com/HarpyWar/cd3676fa4916ea163c50) |
| Base image      | Ubuntu 16.04                               |

## Requirements

- Linux host with Docker (and Docker Compose)
- A running PvPGN server with d2cs/d2dbs that this host can reach
- ~3 GB free disk while building, ~1.5 GB for the final image
- Patience for the first build: Wine is compiled from source (~30 min) and ~1 GB of game files is downloaded.
  Later builds reuse the cached layers.

## Quick start

```sh
git clone https://github.com/espenmjos/d2gs.git
cd d2gs
cp .env.example .env
# edit .env and set D2CS_IP to the IP of your PvPGN server
docker compose up -d --build
docker compose logs -f
```

That's it — no files need editing before the build. All settings are read from environment variables when the
container starts, so changing the IP only needs a restart (`docker compose up -d`), not a rebuild.

Without Compose:

```sh
docker build -t d2gs:1.14d .
docker run -d --name d2gs --restart unless-stopped --network host \
  -e D2CS_IP=192.168.1.10 \
  d2gs:1.14d
```

> **Host networking is required.** D2GS tells d2cs which address clients should connect to. Behind Docker's bridge
> network it would report the container's internal IP, and clients can't join games.

## Configuration

| Variable              | Default                        | Description |
|-----------------------|--------------------------------|-------------|
| `D2CS_IP`             | *(required)*                   | IP of the d2cs server. Use the host's LAN/public IP, not `127.0.0.1`. |
| `D2CS_PORT`           | `6113`                         | d2cs port |
| `D2DBS_IP`            | same as `D2CS_IP`              | IP of the d2dbs server |
| `D2DBS_PORT`          | `6114`                         | d2dbs port |
| `D2CS_SECRET`         | *(empty)*                      | Shared secret; must match `d2gs_password` in `d2cs.conf` |
| `MAX_GAMES`           | `50`                           | Max concurrent games |
| `MAX_GAME_LIFE`       | `14400`                        | Max game lifetime in seconds |
| `MAX_PREFER_USERS`    | `180`                          | Preferred max number of players |
| `MOTD`                | `Welcome to Diablo II!`        | Message shown when joining a game |
| `ADMIN_PORT`          | `8888`                         | Telnet admin console port |
| `ADMIN_PASSWORD_HASH` | hash of `abcd123`              | Admin console password hash |

### Advanced: custom config files

Mount a directory at `/config` to override files completely:

| File in `/config` | Effect |
|-------------------|--------|
| `d2gs.reg`        | Used instead of the generated registry settings (env vars are then ignored) |
| `d2server.ini`    | Replaces D2GS's game rules / bug fixes config |
| `d2warden.ini`    | Replaces the anti-hack (Warden) config |

To start from the defaults, copy them out of the image:

```sh
mkdir config
docker run --rm --entrypoint cat d2gs:1.14d d2server.ini > config/d2server.ini
```

Then uncomment the `volumes:` section in `docker-compose.yml`.

## PvPGN side

The PvPGN server must allow this game server to connect. Set the D2GS host IP in:

- `d2cs.conf`: `gameservlist = <d2gs ip>`
- `d2dbs.conf`: `gameservlist = <d2gs ip>`
- `realm.conf`: the realm must point to the d2cs address reachable by clients

If you use `D2CS_SECRET`, set the same value as `d2gs_password` in `d2cs.conf`.

### Ports

| Port | Proto | Service |
|------|-------|---------|
| 4000 | TCP   | D2GS game traffic — must be reachable by players |
| 8888 | TCP   | D2GS telnet admin — keep firewalled |
| 6112 | TCP/UDP | bnetd (PvPGN) |
| 6113 | TCP   | d2cs (PvPGN) |
| 6114 | TCP   | d2dbs (PvPGN, only needs to be reachable from D2GS) |

## Admin console

```sh
telnet <host> 8888    # default password: abcd123
```

Change the password from the console, or set `ADMIN_PASSWORD_HASH` to a hash produced by D2GS.

## Troubleshooting

- **Players can see the realm but can't create/join games** — usually `D2CS_IP` points to `127.0.0.1` or a
  container IP, port 4000 is blocked, or the container isn't running with host networking.
- **D2GS can't connect to d2cs** — check that the D2GS host IP is in `gameservlist` in both `d2cs.conf` and
  `d2dbs.conf`, and that `D2CS_SECRET` matches `d2gs_password`.
- **Logs** — `docker compose logs -f`. Set `WINEDEBUG=` (empty) in `.env` for verbose Wine output.

## Why such old versions?

D2GS needs Wine with a patched `server/sock.c`. The patch is written for Wine 2.0.x; it doesn't apply to newer
Wine (tried 5.0.2), and Ubuntu 16.04 is the newest base where this Wine builds cleanly (18.04 untested beyond a
quick attempt). Contributions that move to a newer base are welcome.

## References

- [D2GS installation guide (pvpgn.pro)](https://pvpgn.pro/d2gs_installation.html)
- [Diablo II files CDN](http://cdn.pvpgn.pro/)
- [PvPGN server](https://github.com/pvpgn/pvpgn-server)
- [PvPGN Magic Builder](https://github.com/pvpgn/pvpgn-magic-builder)
- [HarpyWar: D2GS under Wine](https://harpywar.com/?a=articles&b=2&c=2&d=21&lang=en)
- [TurBoss: D2GS under Wine](https://gist.github.com/TurBoss/3624782dd3d50b035e117f232063a999)
- [wwmoraes/pvpgn-server-docker](https://github.com/wwmoraes/pvpgn-server-docker)
- [fw42/diablo2 — Battle.net tools](https://github.com/fw42/diablo2)
