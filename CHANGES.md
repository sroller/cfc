# Changes

## 2026-03-09

### Added Membership Expiry Date Display

- **lib/cfc/db.rb**: Added `expire_date` column to `players` table and updated all player-related queries to include it
- **lib/cfc/commands/show.rb**: Added `Membership` field to player output, displays "LIFE" for members with expiry date more than 50 years in the future
- **lib/cfc/diff.rb**: Added `expire_date` to player data comparison output, displays membership status in diff output
- **lib/cfc/downloader.rb**: Fixed `parse_csv_line` to map `expiry` field from tdlist.txt to `expire_date` key
- **test/test_diff_and_commands.rb**: Updated tests to include `expire_date` in player data

### Added Test Coverage for Membership Expiry Feature

- Added 19 new unit tests for `display_expire_date`, `display_expire_info`, and `is_life_membership?` methods
- Tests cover: regular expiry dates, LIFE membership (>50 years), nil values, empty strings
- All 89 tests pass (0 failures, 0 errors)
- Coverage increased from 70.25% to 71.35%

### Database Migration

- Added `expire_date` column to existing production database at `/var/lib/chess/cfc_ratings.db`

### Reimported tdlist.txt with Expiry Dates

- Reimported cached tdlist.txt file with fixed expiry date mapping
- 65,399 out of 75,592 players now have membership expiry dates
- Examples: 100005 (Charles Birch) - LIFE membership, 169571 (Steffen Roller) - LIFE membership

### Fixed Tests

- Added `expire_date` support to:
  - `get_player` method
  - `get_rating_history_by_date_with_player_info` method
  - `find_players` method
  - `get_players_by_date` method
- Added `display_expire_date` helper to Show command
- Added `display_expire_info` helper to Diff command
