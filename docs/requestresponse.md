# Request & Response Reference

## Request: `Zubr::Parser::Zadanie`

The first argument to every handler. Represents the parsed HTTP request.

### Identity

```alexscript
zad.metoda()          # "GET", "POST", etc.
zad.sciezka()         # "/users/42" (URL-decoded path, no query)
zad.sciezka_surowa()  # "/users/42?q=foo" (raw, with query string)
zad.wersja()          # "HTTP/1.1"
```

### Headers

Header lookup is case-insensitive. Returns `nic` if absent.

```alexscript
zad.naglowek("content-type")       # "application/json"
zad.naglowek("Content-Type")       # same
zad.naglowek("X-Custom-Header")    # nic if not sent
zad.naglowki()                     # full hash, all keys lowercased
```

Multi-value headers (e.g. multiple `Cookie:` lines) are joined with `, ` per RFC 7230.

### Path parameters

Set by the router after matching a parametric or regex route:

```alexscript
serwer.get("/users/:id/posts/:post_id", fn(zad) {
  zad.parametry()["id"]       # "42"
  zad.parametry()["post_id"]  # "100"
})
```

For static routes, `zad.parametry()` returns an empty hash `{}`.

### Query string

Pre-parsed from the path:

```alexscript
# Request: GET /search?q=hello&limit=10

zad.zapytanie()           # {"q": "hello", "limit": "10"}
zad.zapytanie()["q"]      # "hello"
```

All values are strings — there's no automatic type coercion. For numeric query params, parse them yourself:

```alexscript
niech limit = zad.zapytanie()["limit"]
jesli limit != nic to limit = limit.liczba()
```

### Body access

```alexscript
zad.tresc()       # raw body string
zad.dane()        # parsed body, dispatched by Content-Type
```

`tresc()` is always available — it's the bytes the client sent.

`dane()` parses `tresc()` according to `Content-Type`:
- `application/json` → AS hash or array (JSON-parsed)
- `application/x-www-form-urlencoded` → AS hash of fields
- `text/*` → raw string
- anything else → raw string
- empty body → `nic`

If JSON parsing fails (malformed body), `dane()` returns the raw string instead of crashing. Result is cached after first call.

### Convenience field access

```alexscript
zad.pole(klucz)              # zad.dane()[klucz], or nic if missing
zad.pole_lub(klucz, default) # same, with fallback
```

Useful for form handlers:

```alexscript
serwer.post("/login", fn(zad) {
  niech email = zad.pole_lub("email", "")
  niech password = zad.pole_lub("password", "")
  # ...
})
```

### Cookies

```alexscript
zad.ciasteczka()              # full hash, lazy-parsed on first call
zad.ciasteczko("session_id")  # value or nic
```

Cookie values are URL-decoded. For signed sessions, use the session API instead — see [Sessions & Cookies](reference-sessions-cookies.md).

### Sessions

If the session middleware is mounted:

```alexscript
zad.sesja()  # Sesja instance, never nic when middleware is active
```

See [Sessions & Cookies](reference-sessions-cookies.md) for the `Sesja` API.

### Connection metadata

```alexscript
zad.czy_keep_alive()  # true for HTTP/1.1 default; false if Connection: close
```

### JSON helper (lower-level)

```alexscript
zad.json()  # parses tresc() as JSON, raises if not valid or wrong Content-Type
```

Prefer `zad.dane()` — it's safer and handles non-JSON bodies gracefully.

## Response: `Zubr::Odpowiedz`

The return value of every handler.

### Construction

Direct construction is rare — usually you'll use a factory. But for full control:

```alexscript
niech odp = Zubr::Odpowiedz.nowy(status, tresc)
odp.naglowek("Content-Type", "text/plain")
odp.naglowek("X-Custom", "value")
zwroc odp
```

### Static factories

```alexscript
Zubr::Odpowiedz.tekst(status, body)
# Content-Type: text/plain; charset=utf-8

Zubr::Odpowiedz.json(status, dane)
# Content-Type: application/json; charset=utf-8
# `dane` can be a hash, array, or any JSON-serializable AS value

Zubr::Odpowiedz.html(status, body)
# Content-Type: text/html; charset=utf-8

Zubr::Odpowiedz.przekieruj(url)
# 302 Found, Location: <url>

Zubr::Odpowiedz.brak_zawartosci()
# 204 No Content, no body

Zubr::Odpowiedz.plik(sciezka)
# Reads file from disk, sets Content-Type from extension.
# For files > 64KB, switches to streaming mode automatically.
# Returns 404 if file doesn't exist, 403 if it's a directory.
```

### Setting headers

```alexscript
odp.naglowek("X-Custom-Header", "value")
odp.ustaw_typ("application/xml")  # shortcut for Content-Type
```

Both return `sam` for chaining.

### Setting/replacing body

```alexscript
odp.ustaw_tresc("new body")
```

### Connection control

```alexscript
odp.zamknij()       # forces Connection: close on this response
odp.czy_zamyka()    # current state
```

Use this if your handler decides the connection shouldn't be reused (e.g. error response with sensitive state).

### Cookies

```alexscript
odp.ustaw_ciasteczko(nazwa, wartosc, opcje)
```

Where `opcje` is a hash with optional keys:
- `max_age` — integer, seconds until expiry
- `expires` — string in HTTP date format
- `path` — string, defaults to `/`
- `domain` — string
- `same_site` — `"Strict"`, `"Lax"`, or `"None"`
- `http_only` — `prawda` to set the `HttpOnly` flag
- `secure` — `prawda` to set the `Secure` flag

Example:

```alexscript
odp.ustaw_ciasteczko("session_id", "abc123", {
  "max_age": 3600,
  "http_only": prawda,
  "secure": prawda,
  "same_site": "Strict"
})
```

Multiple cookies become multiple `Set-Cookie:` headers in the response.

To delete a cookie:

```alexscript
odp.usun_ciasteczko("session_id")
```

This sets `Max-Age=0` and `Path=/`, which most browsers treat as immediate deletion.

## Content negotiation

When one endpoint should serve different formats based on the client's `Accept:` header:

```alexscript
serwer.get("/profile/:id", fn(zad) {
  niech user = znajdz(zad.parametry()["id"])

  zwroc Zubr::Odpowiedz.zaleznie_od(zad, {
    "json": fn() {
      zwroc Zubr::Odpowiedz.json(200, user)
    },
    "html": fn() {
      zwroc Zubr::Odpowiedz.html(200, "<h1>" + user["imie"] + "</h1>")
    },
    "tekst": fn() {
      zwroc Zubr::Odpowiedz.tekst(200, user["imie"])
    }
  })
})
```

`zaleznie_od` parses the `Accept:` header (including q-values and type wildcards), picks the best match from your map, and calls the corresponding callback.

Supported aliases (mapped to MIME types internally):

| Alias | MIME |
|---|---|
| `"json"` | `application/json` |
| `"html"` | `text/html` |
| `"tekst"` | `text/plain` |
| `"xml"` | `application/xml` |
| `"csv"` | `text/csv` |
| `"binarny"` | `application/octet-stream` |

Anything else is passed through as a literal MIME type.

Negotiation rules:
- `*/*` matches anything — picks first in your map
- `text/*` matches any `text/...` — picks first matching alias
- Quality values (`q=0.9`) are honored, highest q wins
- If no `Accept:` header, picks the first alias in your map
- If no match, picks the first alias in your map (lenient — never returns `406`)

## File serving

### Single file

```alexscript
serwer.get("/welcome", fn(zad) {
  zwroc Zubr::Odpowiedz.plik("./public/welcome.html")
})
```

### Directory

```alexscript
serwer.pliki_statyczne("/assets", "./public")
```

Both are documented in detail in [Server reference](reference-server.md).

### Manual streaming

For custom streaming scenarios (e.g. generating data on the fly), construct a streaming response:

```alexscript
serwer.get("/big-data", fn(zad) {
  niech licznik = 0
  niech total = 1000000

  niech generator = fn() {
    jesli licznik >= total to zwroc nic
    licznik = licznik + 1
    zwroc "line " + licznik.napis() + "\n"
  }

  niech odp = Zubr::Odpowiedz.nowy(200, "")
  odp.ustaw_typ("text/plain")
  odp.ustaw_stream(generator, total * 20)  # 20 = approx bytes per line
  zwroc odp
})
```

`ustaw_stream(source, total_size)`:
- `source` is a function `fn() -> next_chunk_string or nic when done`
- `total_size` is sent as `Content-Length`

The connection loop sends headers, then calls `source()` repeatedly until it returns `nic`, writing each chunk directly to the socket. Memory usage stays constant regardless of total response size.

## Status codes

Zubr ships with predefined status lines for the most common codes:

```
100 Continue
200 OK
201 Created
204 No Content
301 Moved Permanently
302 Found
304 Not Modified
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
405 Method Not Allowed
408 Request Timeout
411 Length Required
413 Payload Too Large
414 URI Too Long
431 Request Header Fields Too Large
500 Internal Server Error
501 Not Implemented
503 Service Unavailable
504 Gateway Timeout
```

For codes outside this list, Zubr generates `HTTP/1.1 <code> Unknown` automatically.

## Headers automatically added

The following headers are added to every response unless you set them yourself:

- `Content-Length` — calculated from body size (or stream size for streaming)
- `Date` — current time in HTTP date format (cached for 1 second under load)
- `Server: Zubr/1.0`
- `Connection` — `keep-alive` for HTTP/1.1, `close` if `odp.zamknij()` was called

If you set `Content-Length`, `Date`, `Server`, or `Connection` manually, your value wins.