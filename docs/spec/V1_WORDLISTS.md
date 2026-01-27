# Built-in Wordbooks (V1)

## Data source
- Primary: NYIST-OS/WordList (MIT License)
  - Contains: CET-4, CET-6, 考研英语一, 考研英语二, etc.

## How we include it
- Vendor the needed lists into app resources (text/json)
- Keep upstream LICENSE in: third_party/wordlists/ (or third_party/licenses/)
- Add NOTICE in app About / Settings > Licenses (if exists)

## Update policy (V1)
- Built-in packs ship with the app
- User can still import custom wordbooks (existing feature)
