# YouTube Zapret strategy selector for PassWall

This script tries multiple Zapret strategies to unlock YouTube on OpenWrt. If a working
strategy is found, it keeps Zapret enabled and removes YouTube domains from PassWall
Direct List. If no strategy works, it disables Zapret and adds YouTube domains to PassWall
Direct List.

## Script

`/usr/share/passwall/youtube_zapret_strategy.sh`

## Configuration

Environment variables (optional):

- `YOUTUBE_TEST_URL` (default: `https://www.youtube.com/generate_204`)
- `STRATEGY_SETTLE_SEC` (default: `3`)
- `PASSWALL_RELOAD` (default: `0`)

## Run

```sh
/usr/share/passwall/youtube_zapret_strategy.sh
```

Example with PassWall reload after Direct List changes:

```sh
PASSWALL_RELOAD=1 /usr/share/passwall/youtube_zapret_strategy.sh
```

## Notes

- Strategies are taken from `/etc/zapret/strategies.list` when available. Otherwise a
  built-in list is used.
- The script writes a managed block in `/usr/share/passwall/rules/direct_host` between:
  `# BEGIN PASSWALL YOUTUBE DIRECT` and `# END PASSWALL YOUTUBE DIRECT`.
