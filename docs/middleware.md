# Middleware Reference

Middleware is a function that runs around every handler, with access to both the request before dispatch and the response after. Use it for cross-cutting concerns: logging, authentication, rate limiting, response transformations.

## The middleware contract

A middleware is a function with this signature:

```alexscript
fn(zad, dalej) {
  # ...code that runs before the handler...
  niech odp = dalej(zad)
  # ...code that runs after the handler...
  zwroc odp
}
```

`dalej` is the next handler in the chain. Always call it exactly once, unless you intend to short-circuit (e.g. CORS preflight, rate limit exceeded, auth failure).

## Registration

```alexscript
serwer.middleware(mw)
```

The order matters. The **first** middleware registered runs **outermost**, the **last** runs **innermost** (closest to the handler).

```alexscript
serwer.middleware(A)  # A runs first on the way in, last on the way out
serwer.middleware(B)
serwer.middleware(C)  # C runs last on the way in, first on the way out
serwer.get("/", handler)
```

Request flow: `A → B → C → handler → C → B → A → response`.

## Built-in middleware

### `Zubr::Middleware::Log::standardowy()`

Logs every request with method, path, status, and elapsed time:

```
[15:30:42] GET /api/users -> 200 1.23ms
[15:30:43] POST /api/users -> 201 4.56ms
[15:30:44] GET /api/missing -> 404 0.12ms
```

```alexscript
serwer.middleware(Zubr::Middleware::Log::standardowy())
```

For zero output (e.g. during tests):

```alexscript
serwer.middleware(Zubr::Middleware::Log::cichy())
```

The silent variant is a no-op — it just calls `dalej(zad)` and returns. Useful as a placeholder so you can swap loggers without restructuring.

### `Zubr::Middleware::CORS::pozwol(origins)`

Adds CORS headers and handles `OPTIONS` preflight requests.

```alexscript
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
# Allow any origin

serwer.middleware(Zubr::Middleware::CORS::pozwol([
  "https://myapp.com",
  "https://www.myapp.com"
]))
# Whitelist specific origins
```

Behaviors:
- For `OPTIONS` requests, returns `204` with full CORS headers (preflight). The actual handler is not invoked.
- For other requests, runs the handler then adds `Access-Control-Allow-Origin` to the response if the request's `Origin` is allowed.
- If `Origin` is not allowed (or not sent), no CORS headers are added — the response is delivered normally, but the browser will block it for cross-origin clients.

Allowed methods sent in preflight: `GET, POST, PUT, PATCH, DELETE, OPTIONS`.
Allowed headers sent in preflight: `Content-Type, Authorization`.
Max-Age: `86400` (24 hours).

For finer control, write your own CORS middleware — the built-in is opinionated.

### `Zubr::Middleware::RateLimit::na_ip(limit, okno_sekund)`

Per-IP request counter. Identifies clients by `X-Forwarded-For` header (or `"unknown"` if absent — for direct connections without a reverse proxy, all clients share one bucket).

```alexscript
# 100 requests per 60 seconds per IP
serwer.middleware(Zubr::Middleware::RateLimit::na_ip(100, 60))
```

When a client exceeds the limit, returns `429 Too Many Requests` with `Retry-After: <okno_sekund>`. Successful responses get:

- `X-RateLimit-Limit: 100`
- `X-RateLimit-Remaining: 87`

The store is in-memory and per-process. Restarting the server resets all counters. Counters reset per IP after `okno_sekund` seconds since the bucket started.

**Caveat for benchmarking**: `ab -c 50` on the same machine will hit the limit instantly. For benchmarking, comment out this middleware or set the limit very high (e.g. `na_ip(1000000, 60)`).

**Production note**: if Zubr is behind a reverse proxy (Nginx, Caddy, Cloudflare), `X-Forwarded-For` is set correctly. For direct exposure, you'd need access to the TCP peer address — not currently exposed at the AS level. This is a known limitation.

### `Zubr::Middleware::Sesja::standardowa(sekret)`

Mounts session middleware with HMAC-signed cookies. Documented in detail in [Sessions & Cookies](reference-sessions-cookies.md).

```alexscript
serwer.middleware(Zubr::Middleware::Sesja::standardowa("your-secret-key"))
```

A configurable variant exists for non-default cookie name or expiration:

```alexscript
serwer.middleware(Zubr::Middleware::Sesja::konfigurowalna(sekret, "_my_session", 7200))
```

## Writing your own middleware

A middleware is just a function. Define it inline or as a factory.

### Inline

```alexscript
serwer.middleware(fn(zad, dalej) {
  pokazl "Got request: " + zad.metoda() + " " + zad.sciezka()
  niech odp = dalej(zad)
  pokazl "Sent response: " + odp.status().napis()
  zwroc odp
})
```

### Factory pattern

For middleware with configuration:

```alexscript
modul MojaApp {
  modul Middleware {
    funkcja wymagaj_naglowka(nazwa) {
      zwroc fn(zad, dalej) {
        jesli zad.naglowek(nazwa) == nic {
          zwroc Zubr::Odpowiedz.json(400, {
            "error": "missing required header: " + nazwa
          })
        }
        zwroc dalej(zad)
      }
    }
  }
}

serwer.middleware(MojaApp::Middleware::wymagaj_naglowka("X-API-Key"))
```

The factory takes config arguments and returns the actual middleware function. The closure captures the config for use on every request.

### Short-circuiting

Don't call `dalej(zad)` if you want to skip the handler:

```alexscript
funkcja wymagaj_jsona() {
  zwroc fn(zad, dalej) {
    niech ct = zad.naglowek("content-type")
    jesli zad.metoda() == "POST" lub zad.metoda() == "PUT" {
      jesli ct == nic lub !ct.zawiera("application/json") {
        zwroc Zubr::Odpowiedz.json(415, {
          "error": "Content-Type must be application/json"
        })
      }
    }
    zwroc dalej(zad)
  }
}
```

### Modifying the response

Run the handler, then modify what comes back:

```alexscript
funkcja dodaj_naglowek_versii() {
  zwroc fn(zad, dalej) {
    niech odp = dalej(zad)
    odp.naglowek("X-API-Version", "2.1")
    zwroc odp
  }
}
```

### Authentication middleware

A common pattern:

```alexscript
funkcja wymagaj_uwierzytelnienia() {
  zwroc fn(zad, dalej) {
    niech token = zad.naglowek("authorization")
    jesli token == nic {
      zwroc Zubr::Odpowiedz.json(401, { "error": "auth required" })
    }

    niech uzytkownik = sprawdz_token(token)
    jesli uzytkownik == nic {
      zwroc Zubr::Odpowiedz.json(401, { "error": "invalid token" })
    }

    # Pass the user along to the handler.
    # We piggyback on the session API for this.
    zad.sesja().ustaw("uzytkownik", uzytkownik)
    zwroc dalej(zad)
  }
}
```

Then handlers can do `zad.sesja().pobierz("uzytkownik")` to get the authenticated user.

### Per-route vs global middleware

Zubr's middleware applies to **every** route — there's no built-in scoping. If you want middleware to only run on `/api/*`, check the path inside the middleware:

```alexscript
funkcja chron_api(faktyczny_mw) {
  zwroc fn(zad, dalej) {
    niech sciezka = zad.sciezka()
    niech jest_api = falsz
    jesli sciezka.dlg() >= 5 {
      niech prefix = sciezka.wycinek(0, 4)
      jesli prefix == "/api" to jest_api = prawda
    }

    jesli jest_api to zwroc faktyczny_mw(zad, dalej)
    zwroc dalej(zad)
  }
}

serwer.middleware(chron_api(Zubr::Middleware::RateLimit::na_ip(100, 60)))
```

This is verbose enough that you might prefer to apply such logic at the handler level. For now, Zubr keeps middleware simple.

## Composition tips

### Order matters

Register loggers first, so they see everything (including responses from other middleware):

```alexscript
serwer.middleware(Zubr::Middleware::Log::standardowy())  # outermost
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
serwer.middleware(Zubr::Middleware::RateLimit::na_ip(100, 60))
serwer.middleware(Zubr::Middleware::Sesja::standardowa(sekret))  # innermost
```

This way, even rate-limited requests get logged.

### One middleware per concern

Don't bundle unrelated logic into one middleware. Compose them:

```alexscript
serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(MojaApp::Middleware::wymagaj_jsona())
serwer.middleware(MojaApp::Middleware::wymagaj_uwierzytelnienia())
serwer.middleware(MojaApp::Middleware::audit_log())
```

Each is independently testable and replaceable.

### Avoid heavy computation in outer middleware

Outer middleware runs on every request, including those rate-limited or auth-rejected. If your outer middleware does an expensive operation, a flood of bad requests will hammer it. Move heavy work inward, after rate limiting and auth.

### Closures over loop variables

If you build middleware in a loop, factor the inner closure into a separate function — see the `Middleware::zbuduj` implementation for reference. Otherwise all closures share the loop's mutable state.