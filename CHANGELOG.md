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
- Deduplicate rating records (only save when ratings actually change)
- 75,391 unique players tracked with 111,393 rating snapshots

## [0.2.1] - 2026-03-02

- Fix `diff` command to display player names instead of CFC IDs only
- Add filtering for malformed CSV entries with invalid name data
- Updated diff output to show "Name" format (e.g., "Aadhya Aadhithya")
- Removed duplicate method definitions in diff.rb
- Filtered out 10 invalid entries from new players list (516 → 506)

## [0.1.0] - 2026-03-01

- Initial release
