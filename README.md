# Maru Manga Source Repository

`metadata.json` is the versioned catalog consumed by MaruManga Downloader. It contains adapter identifiers and validated configuration only. The plugin never downloads or executes Lua code from this repository; executable adapters are bundled and reviewed in the plugin. Per-source Lua files are maintained here as source material and mirrored into the plugin.

Each source has its own integer `version` and `metadata.json`. Increment the source version when its profile or behavior changes; increment the root catalog version when catalog entries change. Komiku currently uses a bundled native adapter and supports Indonesian public pages. JavaScript-rendered pages, anti-bot challenges, and authenticated content are unsupported.
