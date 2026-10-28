# docs.digdir.no Markdown mirror

A weekly GitHub Pages build that publishes a Markdown copy of every page on [docs.digdir.no](https://docs.digdir.no/), and a Markdown sitemap, for ingestion by retrieval tools.

- **Content:** [`felleslosninger/docs`](https://github.com/felleslosninger/docs) (`gh-pages`), built with Jekyll and [`_plugins/markdown_output.rb`](_plugins/markdown_output.rb). For each Markdown page, the plugin writes the page source with Liquid rendered (links and includes resolve), under a YAML frontmatter block with the page's title, description, summary and product.
- **Paths:** `/docs/<product>/<page>.html` becomes `/docs/<product>/<page>.md`; a directory page becomes `<dir>/index.md`.
- **Entry point:** `sitemap-markdown.xml`, with absolute URLs.
- **Only Markdown is published.** No HTML copy of the site is served here.
- **Schedule:** Mondays 01:00 UTC, plus manual runs (`workflow_dispatch`).

The canonical site is docs.digdir.no; cite that, not this mirror.
