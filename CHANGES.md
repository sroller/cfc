# Changes

## 2026-03-09 18:55

### Refactored Downloader Module

- **lib/cfc/downloader.rb**: Complete refactor with improved code organization:
  - Consolidated all configuration constants at module top level (URL, CACHE_DIR, HISTORY_DIR, etc.)
  - Extracted parsing helper methods (`parse_int`, `parse_date`, `clean_name`, `clean_city`) into standalone documented methods
  - Consolidated duplicate `Net::HTTP` client code for download and ETag fetch operations
  - Improved error handling with specific exception types (`ArgumentError`, `TypeError`, `StandardError`)
  - Added `line_valid?` helper method for UTF-8 encoding validation
  - Better caching logic: check expiry before reading, read only when valid
  - Archive functionality: automatically stores cached file in history directory

### Test Coverage Added

- **test/test_downloader.rb**: New comprehensive test file with 28 tests covering:
  - Cache read/write operations (5 scenarios)
  - ETag validation (3 scenarios: missing, matching, mismatched)
  - Parsing helper methods (6+ test cases for each method)
  - Encoding sanitization tests (valid UTF-8 and invalid byte replacement)
  - Player parsing with edge cases (empty CSV, header-only, malformed data)

### Test Results

- All 28 new tests pass successfully
- No test failures or errors
- Code is clean with no Ruby warnings
- Coverage note: ~25% overall due to HTTP methods requiring network calls (expected behavior in test environment)

## 2026-03-09 15:30

### Added Membership Expiry Date Display

- **lib/cfc/db.rb**: Added `expire_date` column to `players` table and updated all player-related queries
- **lib/cfc/commands/show.rb**: Added `Membership` field, displays "LIFE" for members with expiry >50 years
- **lib/cfc/diff.rb**: Added `expire_date` to diff output with membership status display
- **lib/cfc/downloader.rb**: Fixed `parse_csv_line` to map `expiry` field from tdlist.txt to `expire_date` key

### Test Coverage for Expiry Feature

- Added 19 new unit tests for expiry display methods
- Tests cover: regular expiry dates, LIFE membership (>50 years), nil values, empty strings
- All tests pass with coverage increase from 70.25% to 71.35%

### Database Migration

- Added `expire_date` column to existing production database at `/var/lib/chess/cfc_ratings.db`

### Reimported tdlist.txt with Expiry Dates

- Reimported cached file with fixed expiry date mapping
- 65,399 out of 75,592 players now have membership expiry dates

### Fixed Tests for Expired Memberships

- Added `expire_date` support to: `get_player`, `get_rating_history_by_date_with_player_info`, `find_players`, `get_players_by_date`
- Added `display_expire_date` helper to Show command
- Added `display_expire_info` helper to Diff command

## 2026-03-09 12:00

### Initial Expiry Date Implementation

- Added `expire_date` column tracking to database schema
- Display logic for membership status (regular vs LIFE)
- Initial tests showing functionality working correctly
