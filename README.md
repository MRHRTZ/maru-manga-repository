# Maru Manga Sources

This is the initial local Git repository for Maru Manga Reader source catalogs. Publish it separately and configure its raw `metadata.json` HTTPS URL in the plugin when a public repository exists. The bundled copy of the catalog is the initial default; no unpublished remote URL is assumed.

`metadata.json` contains `schema_version`, a stable repository `id`, a human-readable `name`, an increasing integer `version`, and a `sources` array. Every source has a stable `id`, `name`, integer `version`, `adapter`, HTTPS `base_url`, and optional `languages` and declarative `profile`. Increase the repository version when its contents change and the source version when that source changes. The client rejects a repository identity change or version rollback. Source IDs must be unique in a catalog; an installed ID cannot be silently taken over by another repository.

Supported adapter names are `mangadex`, `madara`, and `generic`. MangaDex has a reserved ID and API host. Generic and Madara entries may supply URL patterns, CSS selectors, image attributes, and explicit image hosts as data. Profiles cannot include executable code. Source sites vary; validate a profile against a source the user is permitted to access.

The MangaDex Lua files here are reference source code, released under this repository's license. Maru Manga Reader never downloads and executes them: installed entries select compatible adapters already included in the plugin. Updating adapter code requires a trusted plugin release. No JavaScript, authentication bypass, paywall circumvention, or DRM support is provided.

MangaDex is a third-party service; use remains subject to its applicable terms.
