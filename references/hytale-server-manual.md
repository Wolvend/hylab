# Hytale Server Manual - Verified Notes (for Hylab)

Last verified: 2026-02-02
Source: Hypixel Studios Support - "Hytale Server Manual"

## Key Requirements
- Java 25 is required for dedicated servers (Adoptium recommended).
- Minimum 4GB RAM; x64 and arm64 are supported.
- Monitor CPU/RAM; tune heap size with -Xmx.

## Server Files
Two supported approaches:
1) Copy from launcher install (quick testing).
2) Use the Hytale Downloader CLI (production, easier updates).

Launcher paths (from official manual):
- Windows: %appdata%\\Hytale\\install\\release\\package\\game\\latest
- Linux: $XDG_DATA_HOME/Hytale/install/release/package/game/latest
- macOS: ~/Application Support/Hytale/install/release/package/game/latest

Downloader CLI commands (from manual):
- ./hytale-downloader
- ./hytale-downloader -print-version
- ./hytale-downloader -version
- ./hytale-downloader -check-update
- ./hytale-downloader -download-path game.zip
- ./hytale-downloader -patchline pre-release
- ./hytale-downloader -skip-update-check

## Launch & Auth
Start command (recommended):
  java -XX:AOTCache=HytaleServer.aot -jar HytaleServer.jar --assets Assets.zip

First-time authentication:
  /auth login device
This uses device code flow. Auth is required for service APIs.
Limit: 100 servers per game license (per manual).

## Networking
- Default port: 5520
- Protocol: QUIC over UDP (not TCP)
- Bind via: --bind 0.0.0.0:5520

## Firewall Examples (manual)
Windows:
  New-NetFirewallRule -DisplayName "Hytale Server" -Direction Inbound -Protocol UDP -LocalPort 5520 -Action Allow
Linux (iptables):
  sudo iptables -A INPUT -p udp --dport 5520 -j ACCEPT
Linux (ufw):
  sudo ufw allow 5520/udp

## Files & Directories (server root)
- .cache/ : optimized cache
- logs/ : server logs
- mods/ : installed mods
- universe/ : world + player data
- config.json, permissions.json, whitelist.json, bans.json

## Tips & Tricks
- Disable Sentry for active plugin dev: --disable-sentry
- AOT cache improves boot times: -XX:AOTCache=HytaleServer.aot
- View distance drives RAM usage; recommended max: 12 chunks (384 blocks)

## Multiserver Architecture (high-level)
- Player referral: PlayerRef.referToServer(host, port, payload)
- Connection redirect: PlayerSetupConnectEvent.referToServer(host, port, payload)
- Payload goes through client; sign payloads (HMAC) for tamper detection.
- Proxy support: QUIC (Netty) + protocol packets in HytaleServer.jar

## Protocol & Config Notes
- Protocol hash must match between client and server.
- Config files are read on startup and may be overwritten if edited live.

## Maven Artifact (from manual)
Release repo:
  https://maven.hytale.com/release
Pre-release repo:
  https://maven.hytale.com/pre-release
Metadata (release):
  https://maven.hytale.com/release/com/hypixel/hytale/Server/maven-metadata.xml
Metadata (pre-release):
  https://maven.hytale.com/pre-release/com/hypixel/hytale/Server/maven-metadata.xml

## Future Additions (manual)
- Server discovery, parties, integrated payments
- SRV record support (not yet supported)
- First-party API endpoints (planned)

## User-Pasted Excerpt (condensed)
The pasted manual text matches the official manual for:
- Java 25 requirement and 4GB minimum
- Default UDP/QUIC port 5520 and --bind usage
- AOT cache and --disable-sentry guidance
- Launcher paths and downloader CLI
- Device auth flow and 100-server limit
