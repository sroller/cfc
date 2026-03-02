# Cfc

A Ruby gem to manage player data from Chess Canada (CFC).

## Features

- **Download** weekly CFC rating lists from Google Storage with ETag-based caching
- **SQLite database** for storing player ratings with date tracking
- **Rating history** - tracks full history per player (rating, active_rating, fide_rating over time)
- **Diff command** - compare rating snapshots between dates with player details
- **Find command** - search players by name, province, or city
- **Show command** - display detailed player information
- **Cleanup command** - remove duplicate rating entries
- **Local caching** - ETag-based caching to avoid unnecessary downloads
- **Archive history** - all downloads saved to `~/.cfc-history/` for data recovery

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cfc'
```

And then execute:

```bash
bundle install
```

Or install it directly:

```bash
gem install cfc
```

## Usage

### Download Rating Data

Fetch the latest CFC rating list and store it in the database:

```bash
cfc download
```

This will:
- Download the latest rating list from Google Storage (if changed)
- Store player ratings in SQLite database
- Apply deduplication (only saves when ratings actually change)
- Archive the download to `~/.cfc-history/tdlist-YYYYMMDD.txt`

Options:
- `--force` - Force download even if cache is valid
- `--cron` - Silent mode for cronjobs (exits 0 if new data, 1 if no change)

### Compare Rating Snapshots

Compare ratings between two dates:

```bash
cfc diff --from 20190909 --to 20260301
```

Or use default dates (compares latest two available snapshots):

```bash
cfc diff
```

The diff command shows:
- **New Players** - players appearing in the later list
- **Retired Players** - players no longer in the list (marked as retired)
- **Changed Players** - players with rating changes, showing:
  - Player name and city
  - Only ratings that actually changed

Options:
- `--from DATE` - Starting date (YYYYMMDD)
- `--to DATE` - Ending date (YYYYMMDD)
- `--ids ID1,ID2,...` - Filter to specific CFC IDs
- `--ids-file FILE` - Read CFC IDs from file

### Example Output

```
=== Rating Changes ===

New Players: 506
  + 199938 Wil Adams (Toronto): Rating: 0, Active: 928
  + 199144 Azeez Agbaje (Vancouver): Rating: 1755, Active: 0

Changed Players: 2864
  151181 Shabnam Abbarin (Toronto):
         Rating: 1609 -> 1648
  134333 Daniel Abrahams (Calgary):
         Rating: 2210 -> 2198, Active: 2239 -> 2245

Summary:
  New: 506
  Changed: 2864
```

### Search for Players

Find players by name, province, or city:

```bash
# Search by first name
cfc find --first-name Elvis

# Search by last name
cfc find --last-name Smith

# Search by province
cfc find --province ON

# Search by city
cfc find --city Toronto

# Combine filters
cfc find --last-name Roller --province ON
```

### Show Player Details

Display detailed information for a specific player:

```bash
cfc show 151181
```

### Show Rating History

View rating history for a player:

```bash
# Full history
cfc history 151181

# Date range
cfc history 151181 --from 2024-01-01 --to 2024-12-31
```

### Cleanup Duplicate Ratings

Remove duplicate rating entries (keeps oldest when ratings unchanged):

```bash
cfc cleanup
```

## Architecture

### Database Schema

The SQLite database contains two tables:

**player_ratings**
- `cfc_id` - unique player identifier (CFC membership number)
- `rating` - current rating
- `active_rating` - active rating
- `fide_rating` - FIDE rating
- `rating_date` - date of rating
- `download_date` - date downloaded

**players**
- `cfc_id` - unique player identifier (primary key)
- `last_name` - player surname
- `first_name` - player given name
- `province` - Canadian province
- `city` - city of residence

### File Locations

- **Database**: `cfc_ratings.db` (in current directory)
- **Cache**: `~/.cfc-cache/tdlist.txt`
- **History Archive**: `~/.cfc-history/tdlist-YYYYMMDD.txt`

### Deduplication Logic

Records are only created when a player's ratings actually change. If multiple rating snapshots have the same rating values, only the oldest record is kept.

## Development

Run tests:

```bash
rake test
```

Build the gem:

```bash
rake build
```

## Statistics

- **75,391** unique players tracked
- **1,078,061** rating snapshots in database (deduplicated)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sroller/cfc.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).