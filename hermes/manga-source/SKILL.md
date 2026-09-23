---
name: manga-source
description: Add or repair a manga website ("source") in Manga Watcher without a browser. Probes a manga page through the app, picks CSS selectors for title, chapter links and preview, verifies them through the app and saves the source. Use when asked to add support for a manga site, when a source is broken or unstable, or when adding a manga fails with "no parser for website".
---

# Manga Watcher sources

Manga Watcher tracks manga by downloading each manga page and extracting three
things with CSS selectors stored per website (source):

- **title** - element with the manga name
- **links** - chapter links, the highest chapter number is the latest chapter
- **preview** - cover image

Your job is to find selectors that work and save them through the app api.

## Ground rules

- **The app is the only thing that fetches pages.** Never download manga pages
  with curl, wget, web tools or a browser to decide anything: the app has a
  different user agent and TLS fingerprint, so a page that loads for you can be
  blocked for the app. Always use `/probe` and `/test`.
- **Nothing is done until `/test` says `"ok": true`.** Your reading of the
  html is a guess, the app's parser decides.
- If a page is blocked or rendered by javascript, **stop and report it**. It
  can't be fixed with selectors.
- New sources are saved directly. **Updating an existing source needs the
  user's explicit approval** (see step 6).

## API

Base url: `http://localhost:8080/api/agent` (use `$MW_API` instead if it is set).
All endpoints take and return JSON. Requests may take up to a minute because the
app downloads pages and previews, use `curl --max-time 180`.

| Endpoint | Body | Returns |
|---|---|---|
| `POST /probe` | `{"url": ...}` | `verdict`, `reason`, `status`, `final_url`, `host`, `existing_source`, `html` |
| `POST /test` | `{"urls": [...], "selectors": {"title", "links", "preview"}}` | `ok` and one report per url |
| `PUT /sources/<host>` | `{"selectors": {...}, "verified_urls": [...], "confirm": false}` | 201 created, 200 updated, 409 needs confirmation, 422 tests failed, 400 bad input |
| `GET /sources` | | all sources with `mangas`, `broken` counts and `sample_urls` |

`verdict` is one of `ok`, `http_error`, `cloudflare`, `captcha`, `js_rendered`
(`/test` also uses `fetch_error`).

A test report looks like:

```json
{
  "url": "https://site.com/manga/foo", "ok": false, "verdict": "ok", "status": 200,
  "title":   {"matches": 2, "value": null, "samples": ["Foo", "Popular"]},
  "links":   {"matches": 140, "with_chapter": 138, "max_chapter": 179,
              "samples": [{"chapter": 179, "href": "/foo/chapter-179", "text": "Chapter 179"}]},
  "preview": {"matches": 1, "url": "https://cdn.site.com/foo.webp",
              "download": {"ok": true, "status": 200, "content_type": "image/webp", "bytes": 48213}},
  "errors":  ["title selector matched 2 elements, expected exactly 1"]
}
```

## How the parser works

Pick selectors with these rules in mind, they are why "correct looking" CSS fails:

- **title** must match **exactly one** element. Only the element's **own text**
  is used, text of nested tags is ignored. If the name is inside a nested
  `<a>` or `<span>`, select that inner element (e.g. `.item-title a`).
- **links**: every matched element's html is searched for `chapter-N` or
  `chapter/N` (N < 1000), otherwise for `Chapter N` in the text. Only integer
  chapters are recognised. Links without a number are ignored, so a slightly
  broad selector is fine, but it must not include links to *other* manga
  (sidebars with "Chapter 44" of popular series will inflate `max_chapter`).
- **preview** must match **exactly one** element. The url is taken from the
  first non-empty of `src`, `data-src`, `data-lazy-src`, `content` (skipping
  `data:` placeholders). `meta[property="og:image"]` is often the most stable
  choice. The app downloads it with a `Referer` of the site, it must return an
  image.
- Selectors are evaluated by Floki: standard CSS selectors work (tag, `.class`,
  `#id`, `[attr]`, `[attr="v"]`, `[attr*="v"]`, descendant, `>`, `+`, `~`,
  `:nth-child()`, `:first-child`, `:not()`, `:has()`, comma groups). Test
  anything unusual.
- Prefer stable, meaningful classes and ids (`#chapterlist a`, `.chapter-list a`).
  Avoid generated ones (`css-1x2y3z`, `sc-AbCd`), long descendant chains and
  positional selectors, they break when the site changes.

## Workflow: add a source

The user gives a manga page url (a page of one manga, with its chapter list).
If they gave a site root, ask for a manga page.

1. **Probe** the page and save the html:

   ```sh
   curl -s --max-time 180 -X POST "${MW_API:-http://localhost:8080/api/agent}/probe" \
     -H 'content-type: application/json' -d '{"url": "<URL>"}' > /tmp/mw_probe.json
   python3 -c 'import json; d = json.load(open("/tmp/mw_probe.json")); open("/tmp/mw_page.html", "w").write(d.pop("html", "")); print(json.dumps(d, indent=1))'
   ```

   - `verdict` not `ok` → stop, report `verdict` and `reason` (see "Reporting").
   - `final_url` on a different host than `host` → the site moved. Tell the
     user and suggest adding the manga with the new domain instead; the source
     must be for the host of the url that will be stored.
   - `existing_source` is set → this is a repair, `/test` the existing
     selectors first. If they pass, tell the user the source already works.

2. **Outline** the page instead of reading the raw html:

   ```sh
   python3 <skill dir>/scripts/outline.py /tmp/mw_page.html
   ```

   It lists meta tags, title candidates, images and link groups ranked by how
   many chapter links they contain. Grep `/tmp/mw_page.html` when you need more
   context around a candidate.

3. **Find a second manga url** on the same site, from a link group with other
   series (related, popular, sidebar) in the outline. Two different manga
   pages are required to save, it prevents selectors that only fit one page.
   Probe it too if in doubt.

4. **Test** candidates on both urls:

   ```sh
   curl -s --max-time 180 -X POST "${MW_API:-http://localhost:8080/api/agent}/test" \
     -H 'content-type: application/json' \
     -d '{"urls": ["<URL1>", "<URL2>"], "selectors": {"title": "...", "links": "...", "preview": "..."}}'
   ```

   Fix what `errors` and the per-field numbers point at and test again. Give
   up after about 6 rounds and report what you found.

5. **Sanity check** what the parser returned, the api can't judge meaning:
   - `title.value` is the manga's name, not the site name or a section header;
   - `links.max_chapter` matches the latest chapter visible on the page and
     `links.samples` are chapters of *this* manga;
   - `preview.url` is this manga's cover, not a logo or another series.

6. **Save**:

   ```sh
   curl -s --max-time 180 -X PUT "${MW_API:-http://localhost:8080/api/agent}/sources/<HOST>" \
     -H 'content-type: application/json' \
     -d '{"selectors": {...}, "verified_urls": ["<URL1>", "<URL2>"]}'
   ```

   The app tests again before saving. For an existing source it also tests up
   to 5 of its mangas (mangas that return 404 are ignored).

   - **201** → created, report success.
   - **409** → the source exists. Show the user `current` vs `proposed`
     selectors and a short summary of the reports, and ask whether to update.
     Only after the user explicitly agrees, repeat the request with
     `"confirm": true`. Updating also clears the "broken" state of the site's
     mangas so they are polled again.
   - **422** → some url failed, the body has the reports. If an *existing*
     manga failed, the new selectors would break it: fix them or report.
   - **400** → bad input, read `error`.

## Workflow: repair broken sources

`GET /sources` and look at sources with `broken > 0`. For each, run the add
workflow starting from one of its `sample_urls`. A broken manga may also be
broken because its url changed (404); `/probe` shows that, it's not a selector
problem.

## Reporting

Keep it short. On success: host, whether created or updated, the selectors,
and for each tested url the parsed title, latest chapter and preview url.

When it can't be done, say why in plain words:

- `cloudflare` / `captcha` - the site only serves pages to real browsers;
- `js_rendered` - the site builds the page with javascript, there is no
  content in the html the app downloads;
- chapter links have no `chapter-N` / `Chapter N` pattern - the app's parser
  can't read chapter numbers on this site, needs a code change;
- `http_error` - the status and url, likely a wrong or removed page.
