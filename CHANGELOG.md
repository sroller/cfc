## [Unreleased]

## [0.2.0] - 2026-03-01

- Add `download` command to fetch weekly CFC rating list from Google Storage
- Add SQLite database module for storing player ratings with date tracking
- Implement CSV parsing with data cleaning (quotes, whitespace, special values)
- Add local caching (~/.cfc-cache) with 7-day expiry
- Add comprehensive tests for downloader and database operations
- Track full rating history per player (rating, active_rating, fide_rating over time)
- Add `diff` command to compare rating lists with optional `--from` and `--to` parameters
- Load fixtures chronologically to build historical rating data
- Store database and backups in `/var/lib/chess/` for backup and debugging

## [0.1.0] - 2026-03-01

- Initial release
