## [Unreleased]

## [0.3.6] - 2026-04-23

### Fixed

- Fixed `fetch_csv` to return sanitized UTF-8 data, preventing `Encoding::CompatibilityError` when parsing newly downloaded rating files
- `parse_ids_file` now aborts with a clear error message when the specified file doesn't exist

### Changed

- Refactored CLI validation into reusable private methods (`validate_format!`, `validate_dates!`, `validate_mutually_exclusive!`, `require_id_or_file!`)
- Replaced `$stderr.puts; exit(1)` patterns with `abort` for cleaner error handling
- Extracted common helpers into `Helpers` module (`normalize_date`, `parse_ids`, `parse_ids_file`, `format_location`, `display_expire`, `output_result`)
- Unified output formatting across `diff`, `history`, `show`, and `find` commands via `Helpers.output_result`
- Refactored `OutputFormatter` with shared `html_page` helper and `HTML_STYLES` constant
- Replaced `$stderr.puts` with `warn` in `cleanup` command
- Added nil/empty guards in `Downloader.parse_players` and `line_valid?`

### Removed

- Remove FIDE rating storage and display from the application
- Remove `fide_rating` column from database schema
- Remove FIDE number and rating parsing from CSV downloader
- Remove FIDE rating from `show`, `history`, and `cleanup` commands

## [0.3.0] - 2026-03-02

### Added

- New `show CFC_ID` command - displays detailed player information
- New `history CFC_ID` command - shows rating history with optional `--from` and `--to` date filters
- New `find` command - search for players by `--last_name`, `--first_name`, `--province`, and/or `--city` (supports partial matches)
- New `cleanup` command - removes duplicate rating entries, keeping only the oldest when ratings haven't changed
- `--ids` option to `diff` command - filter output to specific CFC IDs
- `--ids-file` option to `diff`, `history`, and `show` commands - read CFC IDs from a file
- `--cron` flag to `download` command - silent mode for cronjobs, exits 0 if new data, 1 if no change
- Spinner animation in `diff` command to indicate progress during long operations
- Archived downloads are saved to `~/.cfc-history/tdlist-YYYYMMDD.txt`

### Changed

- Migrated to Thor gem for command line parsing
- CLI now shows help when called without parameters
- Players absent from new downloads are marked as "retired" instead of "removed"
- `diff` command now shows player name, city, and only ratings that actually changed
- Retired players section hidden from summary when count is zero
- Removed redundant `cfc_number` field (CFC ID is the canonical identifier)

### Fixed

- `diff` command now works without arguments - automatically uses the two most recent rating snapshots
- Fixed deduplication logic in `save_players` - now properly checks if ratings changed before inserting
- Fixed database result key handling in `diff` - converts string keys to symbols for consistency
- Fixed fixture loading condition - now checks database state instead of cache file existence
- Fixed SQL parameter binding in `get_current_ratings` - properly expands array for IN clause
- Fixed false "retired" reporting - uses "as-of" date logic instead of exact date matching
- Removed unused CSV parsing methods from `diff.rb`

## [0.2.0] - 2026-03-01

- Add `download` command to fetch weekly CFC rating list from Google Storage
- Add SQLite database module for storing player ratings with date tracking
- Implement CSV parsing with data cleaning (quotes, whitespace, special values)
- Add local caching (~/.cfc-cache) with 7-day expiry
- Add comprehensive tests for downloader and database operations
- Track full rating history per player (rating and active_rating over time)
- Add `diff` command to compare rating lists with optional `--from` and `--to` parameters
- Load fixtures chronologically to build historical rating data
- Store database and backups in `/var/lib/chess/` for backup and debugging
- Deduplicate rating records (only save when ratings actually change)
- 75,391 unique players tracked with 111,393 rating snapshots

## [0.2.2] - 2026-03-02

- Add ETag-based caching to prevent unnecessary downloads
- Add HEAD request to check if remote file has changed before downloading
- Store ETag in separate `.etag` cache file for comparison
- Skip database updates when file hasn't changed
- Preserve all historical data (no database clearing)
- Deduplication now only updates when ratings actually change
- 75,391 unique players tracked with 1,078,061 rating snapshots

## [0.1.0] - 2026-03-01

- Initial release
