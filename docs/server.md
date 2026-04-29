# Server Reference: `Zubr::Serwer`

The `Serwer` class is the main entry point. It owns the routing engine, middleware chain, configuration, and the accept loop.

## Construction

```alexscript
niech serwer = Zubr::Serwer.nowy(port)
```

The constructor takes a single argument — the TCP port. The host defaults to `0.0.0.0` (all interfaces).

## Configuration

### `ustaw_host(host)`

Bind to a specific interface. Common choices:

```alexscript
serwer.ustaw_host("127.0.0.1")  # localhost only — not reachable from network
serwer.ustaw_host("0.0.0.0")    # all interfaces — default
```

Returns `sam` (self), so it chains.

### `ustaw_logger(logger)`

Replace the connection-level logger. Pass an instance of `Zubr::Logger::Standardowy` or `Zubr::Logger::Cichy`, or your own object that responds to `zapisz(zad, odp)`, `blad(zad, e)`, and `info(text)`.

```alexscript
serwer.ustaw_logger(Zubr::Logger::cichy())  # silence connection logs
```

Note: the connection logger is separate from the logging middleware. The connection logger always runs and reports raw HTTP outcomes. The middleware logger (`Zubr::Middleware::Log::standardowy()`) runs in the request pipeline and can be customized further.

## Routing

### Generic route registration

```alexscript
serwer.trasa(metoda, wzor, handler)
```

- `metoda` — HTTP method as uppercase string (`"GET"`, `"POST"`, etc.) or `"*"` to match any method
- `wzor` — path pattern (see Patterns below)
- `handler` — function `fn(zad) { ... zwroc odp }` returning an `Odpowiedz`

Returns `sam`.

### Verb shortcuts

For convenience:

```alexscript
serwer.get(wzor, handler)
serwer.post(wzor, handler)
serwer.put(wzor, handler)
serwer.patch(wzor, handler)
serwer.delete(wzor, handler)
```

All return `sam` for chaining. Internally each calls `trasa("GET", ...)` etc.

### Regex routes

For patterns more complex than `:param` and `*`:

```alexscript
serwer.trasa_regex("GET", Wyrazenie.nowy("^/api/v[0-9]+/.*$"), handler)
```

Named regex captures become entries in `zad.parametry()`. Regex routes are checked **after** static and parametric routes.

### Custom 404 handler

```alexscript
serwer.trasa_404(fn(zad) {
  zwroc Zubr::Odpowiedz.json(404, {
    "error": "not found",
    "path": zad.sciezka()
  })
})
```

Without this, Zubr returns `404 Not Found` with body `Not Found`.

### Static file mounting

```alexscript
serwer.pliki_statyczne(prefix_url, katalog_dyskowy)
```

Mounts a filesystem directory at a URL prefix. Example:

```alexscript
serwer.pliki_statyczne("/static", "./public")
```

`GET /static/css/main.css` serves `./public/css/main.css`.

Features:
- Auto-detect `Content-Type` from extension
- ETag and Last-Modified headers
- Conditional GET (304 Not Modified) on If-None-Match and If-Modified-Since
- Path traversal protection (`..` cannot escape the base directory)
- Streaming for files larger than 64KB (constant memory footprint)
- 403 for directory listing attempts

Internally registers a wildcard route `prefix_url + "/*"`, so `pliki_statyczne` and `trasa` interact normally.

## Patterns

| Pattern | Matches | Captured parameters |
|---|---|---|
| `/users` | exactly `/users` | none — static route |
| `/users/:id` | `/users/42`, `/users/anna` | `id` |
| `/users/:user_id/tasks/:task_id` | `/users/7/tasks/123` | `user_id`, `task_id` |
| `/static/*` | `/static/foo`, `/static/a/b/c` | `wildcard` |

Static routes (no `:` or `*`) are stored in a hash and matched in O(1). Parametric routes are checked in registration order. Regex routes are checked last.

Parameters are accessible via `zad.parametry()` returning a hash:

```alexscript
serwer.get("/users/:id", fn(zad) {
  niech id = zad.parametry()["id"]
  # ...
})
```

## Method handling

### Automatic HEAD support

If a `GET` route is registered, `HEAD` requests on the same path automatically work — Zubr runs the GET handler, strips the body, and returns headers only. You don't need to register `HEAD` separately.

### 405 Method Not Allowed

If a path is registered for some method but the request uses a different one, Zubr returns `405 Method Not Allowed` with an `Allow:` header listing the allowed methods. This works for static routes; parametric routes fall through to `404` (the cost of cross-checking every parametric route per request was deemed not worth it).

## Middleware

```alexscript
serwer.middleware(mw)
```

Adds a middleware to the chain. `mw` is a function `fn(zad, dalej) { ... zwroc odp }` where `dalej` is the next handler in the chain.

Middleware compose **outside-in**: the first registered runs outermost, the last runs innermost (closest to the handler). Call `dalej(zad)` exactly once to invoke the wrapped handler.

See the [Middleware reference](reference-middleware.md) for built-in middleware and how to write your own.

## Lifecycle

### `start()`

Starts the accept loop. Blocks the main thread. Each accepted connection is handed to a fresh Ruby thread that runs the connection loop (parse request → dispatch through middleware → send response → loop on keep-alive).

```alexscript
serwer.start()
```

There is no graceful shutdown via signal in MVP — `Ctrl+C` kills the process immediately. Any in-flight requests are dropped. Sessions and other in-memory state are lost.

### Configuration object

Internally `Serwer` owns a `Konfiguracja` object exposing connection-level limits:

```alexscript
serwer.config().limity().ustaw_max_cialo(20 * 1024 * 1024)  # 20MB max body
serwer.config().ustaw_max_requestow_keepalive(200)
```

Default limits:
- `max_request_line`: 8192 bytes
- `max_naglowek_linia`: 16384 bytes per header line
- `max_naglowki`: 100 headers per request
- `max_cialo`: 10485760 bytes (10MB)
- `max_requestow_keepalive`: 100 requests per connection

These are RFC-aligned defaults. Adjust if you need to accept large bodies (file uploads) or many headers.

## Complete example

```alexscript
import("../lib/zubr")

niech serwer = Zubr::Serwer.nowy(8080)

# Configuration
serwer.ustaw_host("127.0.0.1")
serwer.config().limity().ustaw_max_cialo(50 * 1024 * 1024)

# Middleware (order matters: outermost first)
serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
serwer.middleware(Zubr::Middleware::RateLimit::na_ip(100, 60))

# Static files
serwer.pliki_statyczne("/assets", "./public")

# API routes
serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.html(200, "<h1>Welcome</h1>")
})

serwer.get("/api/users/:id", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, { "id": zad.parametry()["id"] })
})

serwer.post("/api/users", fn(zad) {
  niech dane = zad.dane()
  zwroc Zubr::Odpowiedz.json(201, dane)
})

# Custom 404
serwer.trasa_404(fn(zad) {
  zwroc Zubr::Odpowiedz.json(404, {
    "error": "not_found",
    "path": zad.sciezka()
  })
})

serwer.start()
```