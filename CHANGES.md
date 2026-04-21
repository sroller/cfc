# Changes

## 2026-04-20

### Fixed Download Cron Silent Mode

- **lib/cfc/downloader.rb**: Fixed cron mode to be truly silent
  - Changed `unless cron && result` to `unless cron`
  - Previously output "Loaded latest cached data" even in cron mode
  - Now correctly suppresses all output when `--cron` flag is used

### Removed Non-Functional Cron Mode from Diff Command

- **lib/cfc.rb**: Removed `--cron` option from diff command
- **lib/cfc/diff.rb**: Removed cron-related methods (`run_cron`, `capture_diff_output`, `capture_diff_output_html`, `diff_has_changes?`)
- **README.md**: Removed all cron mode documentation and examples
- **CHANGES.md**: Removed historical entries documenting cron feature
- **test/test_diff_and_commands.rb**: Removed 7 cron-related tests
- Cron mode was non-functional, removed to simplify codebase

### Fixed Downloader Module Namespace

- **lib/cfc/downloader.rb**: Wrapped all methods and constants in `module Downloader` block
  - Previously methods were defined directly under `module Cfc` but referenced as `Cfc::Downloader`
  - This caused `uninitialized constant Cfc::CLI::Downloader` error when running `cfc download`
  - All constants (URL, CACHE_DIR, etc.) and methods (download_and_store, parse_csv_line, etc.) now properly scoped under `Cfc::Downloader`

### Fixed Tilde Expansion in --ids-file Paths

- **lib/cfc/diff.rb**: Added `File.expand_path(filepath)` to `parse_ids_file` method
- **lib/cfc/commands/show.rb**: Added `File.expand_path(filepath)` to `parse_ids_file` method
- **lib/cfc/commands/history.rb**: Added `File.expand_path(filepath)` to `parse_ids_file` method
  - Previously paths like `~/lib/cccg.ids` failed because `~` was not expanded
  - `File.exist?("~/lib/cccg.ids")` returned false, causing ID filtering to be skipped
  - This resulted in showing ALL players instead of just those in the IDs file

### Test Coverage
- **test/test_diff_and_commands.rb**: Added test for tilde expansion in `parse_ids_file`
- All 155 tests pass


### Expired Membership Dates Marked Red in HTML Output

- **lib/cfc/output_formatter.rb**: Added `expire_html_for` helper method
  - Checks if membership date is in the past (before today)
  - Expired dates are wrapped in `<span class="expired">` which displays in red
  - LIFE memberships and future dates display normally
  - Applied to diff (new/retired/changed tables), show, and history commands
  - Added `.expired { color: red; }` CSS class to all HTML output styles
- **test/test_output_formatter.rb**: Added 9 tests for expired membership handling
  - Tests for expired, future, LIFE, nil, empty, and invalid dates
  - Tests for diff and show commands with expired memberships

### Added Email Output (--mail option) to All Commands

- **lib/cfc/mailer.rb**: New mailer module using the Ruby `mail` gem
  - Sends MIME emails with both HTML and plain text parts
  - Plain text part is auto-generated from HTML by stripping tags
  - Supports multiple recipients (comma-separated list)
  - Configurable via environment variables:
    - `CFC_MAIL_FROM`: Sender address (default: `cfc@localhost`)
    - `CFC_SMTP_SERVER`: SMTP server (default: `localhost`)
    - `CFC_SMTP_PORT`: SMTP port (default: `25`)
  - When `--mail` is used without `--format`, defaults to HTML format
  - Email subject includes context (e.g., "Rating Changes (2026-04-09 to 2026-04-16)")
- **lib/cfc.rb**: Added `--mail` option to `diff`, `history`, `show`, and `find` commands
  - Accepts comma-separated list of email addresses
  - All commands send HTML output as email body with auto-generated plain text alternative
- **lib/cfc/diff.rb**: Updated to send email with date range in subject
- **lib/cfc/commands/history.rb**: Updated to send email with player name and optional date range
- **lib/cfc/commands/show.rb**: Updated to send email with player name
- **lib/cfc/commands/find.rb**: Updated to send email with player count
- **cfc.gemspec**: Added `mail ~> 2.8` dependency
- **test/test_mailer.rb**: 15 tests covering mailer functionality

### Usage Examples

```bash
cfc diff --from=20260101 --to=20260420 --mail=user@example.com
cfc history 123456 --mail=admin@example.com,coach@example.com
cfc show 123456 --mail=player@example.com --format=html
cfc find --last_name Smith --mail=club@example.org
```

### Fixed CGI Import for Ruby 4.0

- **lib/cfc/output_formatter.rb**: Changed `require "cgi"` to `require "cgi/escape"` for Ruby 4.0 compatibility

### Date Range and Report Date in Output Headers

- **lib/cfc/output_formatter.rb**: Added `date_range` parameter to all formatters
  - `format` method now accepts `date_range:` keyword argument
  - Diff: Shows date range in HTML title/heading and CSV comment (e.g., "2026-04-09 to 2026-04-16")
  - History: Shows date range when `--from`/`--to` provided, otherwise no range shown
  - Show: Shows report generation date (e.g., "Report: 2026-04-20")
  - Find: Shows report generation date (e.g., "Report: 2026-04-20")
- **lib/cfc/diff.rb**: Passes `"#{from} to #{to}"` as date_range to formatter
- **lib/cfc/commands/history.rb**: Added `build_date_range` helper, passes date_range to formatter
- **lib/cfc/commands/show.rb**: Passes `Date.today` as report date
- **lib/cfc/commands/find.rb**: Passes `Date.today` as report date

### Clean stdout/stderr Separation for Piping and Redirection

- All error and status messages now go to stderr instead of stdout
- Data output (text, html, csv) always goes to stdout
- Spinner only runs when `$stdout.tty?` (interactive terminal)
- This allows clean piping: `cfc diff --format=csv | grep ...` without status messages

**Files changed:**
- **lib/cfc/diff.rb**: Spinner gated on TTY, status/error messages to stderr
- **lib/cfc/downloader.rb**: "Loaded latest cached data" to stderr
- **lib/cfc/commands/cleanup.rb**: All progress/status messages to stderr
- **lib/cfc/commands/history.rb**: Error messages to stderr
- **lib/cfc/commands/show.rb**: Error messages to stderr
- **lib/cfc.rb**: All CLI error/usage messages to stderr
- **test/test_helper.rb**: `capture_io` now captures both stdout and stderr

### Added HTML and CSV Output Formats to All Commands

- **lib/cfc/output_formatter.rb**: New shared formatter module supporting HTML and CSV output
  - HTML output includes styled tables with proper escaping (CGI.escapeHTML)
  - CSV output with header comments and consistent column structure
  - Supports all four data-output commands: diff, history, show, find
- **lib/cfc.rb**: Added `--format` option to `diff`, `history`, `show`, and `find` commands
  - Valid values: `text` (default), `html`, `csv`
  - Validates format value and shows helpful error for invalid values
- **lib/cfc/diff.rb**: Updated `run` method to accept `format` parameter
- **lib/cfc/commands/history.rb**: Updated `run` method with `format` parameter and `capture_player_history` helper
- **lib/cfc/commands/show.rb**: Updated `run` method to accept `format` parameter
- **lib/cfc/commands/find.rb**: Updated `run` method to accept `format` parameter

### Usage Examples

```bash
cfc diff --from=20260101 --to=20260420 --format=csv
cfc diff --from=20260101 --to=20260420 --format=html > changes.html
cfc diff --from=20260101 --to=20260420 --mail=user@example.com
cfc history 123456 --format=csv
cfc history 123456 --mail=admin@example.com,coach@example.com
cfc show 123456 --format=html
cfc show 123456 --mail=player@example.com
cfc find --last_name Smith --format=csv
cfc find --last_name Smith --mail=club@example.org
```

### Test Coverage

- **test/test_output_formatter.rb**: 24 tests covering all format combinations
  - Diff: HTML (new, changed, retired, empty), CSV (new, changed, empty)
  - History: HTML, CSV
  - Show: HTML, CSV
  - Find: HTML (single, multiple), CSV
  - Helpers: expire info, rating change formatting
- All 130 tests pass

### Fixed Date Format Handling in Diff Command

- **lib/cfc/diff.rb**: Added `normalize_date` method to convert `YYYYMMDD` to `YYYY-MM-DD`
  - Previously, passing `--from=20260101` resulted in empty output due to string comparison issues
  - The database stores dates as `YYYY-MM-DD`, but compact format was compared as strings
  - Now both formats are supported transparently

### Added Date Validation and Improved Help Messages

- **lib/cfc.rb**: Added `valid_date_format?` class method for date format validation
  - Validates `--from` and `--to` options in both `diff` and `history` commands
  - Rejects invalid formats with a helpful error message showing expected formats
- Updated help text for `--from` and `--to` to show both supported formats: `YYYY-MM-DD or YYYYMMDD`

### Test Coverage

- Added 4 tests for `normalize_date` method
- All 94 diff tests pass

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
