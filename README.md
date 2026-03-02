# Cfc

A Ruby gem to manage player data from Chess Canada (CFC).

## Features

- **Download** weekly CFC rating lists from Google Storage
- **SQLite database** for storing player ratings with date tracking
- **Rating history** - tracks full history per player (rating, active_rating, fide_rating over time)
- **Diff command** - compare rating snapshots between dates
- **Local caching** - 7-day expiry for cached data

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
- Download the latest rating list from Google Storage
- Load historical fixtures chronologically
- Store player ratings in SQLite database at `/var/lib/chess/cfc_ratings.db`
- Apply deduplication (only saves when ratings actually change)

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
- **Removed Players** - players no longer in the list
- **Changed Players** - players with rating changes, showing:
  - Player name (e.g., "Aadhya Aadhithya")
  - Rating change (old → new)
  - Active rating change

### Example Output

```
=== Rating Changes ===

New Players: 506
  + 199938 (Wil Adams) Rating: 0 Active: 928
  + 199144 (Azeez Agbaje) Rating: 1755 Active: 0

Changed Players: 2864
  151181 (Shabnam Abbarin): 1609 -> 1648
         Active: 1567 -> 1567
  134333 (Daniel Abrahams): 2210 -> 2198
         Active: 2239 -> 2239

Summary:
  New: 506
  Removed: 0
  Changed: 2864
```

## Architecture

### Database Schema

The SQLite database contains two tables:

**player_ratings**
- `cfc_id` - unique player identifier
- `cfc_number` - CFC membership number
- `rating` - current rating
- `active_rating` - active rating
- `fide_rating` - FIDE rating
- `rating_date` - date of rating
- `download_date` - date downloaded

**players**
- `cfc_id` - unique player identifier
- `cfc_number` - CFC membership number
- `last_name` - player surname
- `first_name` - player given name
- `province` - Canadian province
- `city` - city of residence

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
- **111,388** rating snapshots in database
- **5** historical fixture snapshots loaded

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/cfc.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).