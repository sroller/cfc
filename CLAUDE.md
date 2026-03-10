## Project Overview

A Ruby Gem to manage player data from Chess Canada (CFC)

## Change Tracking

After every change you make to the project, append an entry to `CHANGES.md` with:
- Date and time
- Brief description of what was changed and why
- Files affected

Keep entries concise. Do not ask for confirmation before writing to CHANGES.md.

## Architecture

This project is Ruby GEM.

## Testing
- test coverage shall be 90% or better, add or extend existing tests when necessary

## Techstack
- Use Ruby 4.0.1 (managed via rvm)
- Use SQLite as data store
- Use rvm for Ruby version management
- Test framework: Minitest

## Testing
- Test coverage shall be 90% or better (configurable in SimpleCov)
- Tests use `capture_io` helper to capture stdout output
- Create temporary directories with `Dir.mktmpdir` for test isolation
- Clean up with `FileUtils.rm_rf(@tmp_dir)` in teardown

## Testing Commands
- Run all tests: `rake test`
- Test file pattern: `test/test_*.rb` is auto-discovered by Minitest::TestTask

## Common Commands
- Build: rake build
- test: rake
