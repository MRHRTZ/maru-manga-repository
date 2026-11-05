# Source compatibility

The plugin installs source metadata but only runs reviewed adapters bundled with the plugin. Repository Lua files are source mirrors and are never downloaded or executed by the app.

Supported source adapters:

- Komiku: Indonesian public pages plus its reviewed JSON API.
- MangaRock: public English search, popular, latest updates, details, chapter pagination and direct page images.
- MangaMost: the Android app's public MangaMost JSON API. It is independent from the Mangago website.
- Mangago: public `www.mangago.zone` HTML search, work metadata and chapter tables. It is marked NSFW. Certificate validation is skipped only for this source, with HTTPS and exact host allowlists retained. Chapter image URLs are decoded from its AES-encrypted manifest. Images with shuffled tile layouts still need unscrambling before chapters are ready for use.
- WEBTOON: public server-rendered English search, ranking, title details, paginated episodes and viewer image URLs.

Repository and source versions use strict `MAJOR.MINOR.PATCH` values. Legacy integer versions remain readable so existing installations can be updated without losing their profile state.
