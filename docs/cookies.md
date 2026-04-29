# Sessions & Cookies Reference

Zubr ships with two related but separate APIs:

- **Cookies** — low-level read/write of HTTP cookies on individual requests/responses
- **Sessions** — higher-level HMAC-signed sessions with server-side storage, built on top of cookies

Most applications want sessions. Cookies are documented here for completeness and for cases where you need finer control (e.g. setting a tracking cookie that the application reads on the next visit without involving sessions).

## Cookies

### Reading cookies from a request

Inside a handler, request cookies are parsed lazily on first access:

```alexscript
serwer.get("/", fn(zad) {
  niech c = zad.ciasteczka()       # full hash, all values URL-decoded
  niech sid = zad.ciasteczko("session_id")  # single value, or nic
  # ...
})
```

The parser handles RFC 6265 cookie syntax:
- Multiple cookies separated by `;`
- Quoted values are unwrapped
- URL-encoded values are decoded

Both keys and values come back as strings. Cookies that aren't present return `nic`.

### Writing cookies to a response

```alexscript
odp.ustaw_ciasteczko(nazwa, wartosc, opcje)
```

The `opcje` hash supports these keys (all optional):

| Key | Type | Effect |
|---|---|---|
| `max_age` | integer | `Max-Age=N` (seconds until expiry) |
| `expires` | string | `Expires=...` in HTTP date format |
| `path` | string | `Path=...`. Defaults to `/` |
| `domain` | string | `Domain=...` |
| `same_site` | `"Strict"` / `"Lax"` / `"None"` | `SameSite=...` |
| `http_only` | `prawda` | adds `HttpOnly` flag |
| `secure` | `prawda` | adds `Secure` flag |

Example — setting a long-lived preference cookie:

```alexscript
serwer.post("/preferences", fn(zad) {
  niech tryb = zad.pole_lub("tryb", "jasny")
  niech odp = Zubr::Odpowiedz.json(200, { "tryb": tryb })
  odp.ustaw_ciasteczko("tryb", tryb, {
    "max_age": 365 * 86400,
    "path": "/",
    "same_site": "Lax"
  })
  zwroc odp
})
```

### Multiple cookies on one response

Each call to `ustaw_ciasteczko` adds a new `Set-Cookie:` header. Browsers handle multiple `Set-Cookie:` headers independently:

```alexscript
odp.ustaw_ciasteczko("session_id", "abc", { "http_only": prawda })
odp.ustaw_ciasteczko("preferred_theme", "dark", { "max_age": 86400 })
odp.ustaw_ciasteczko("trace_id", "xyz")
```

Wire format:

```
Set-Cookie: session_id=abc; Path=/; HttpOnly
Set-Cookie: preferred_theme=dark; Max-Age=86400; Path=/
Set-Cookie: trace_id=xyz; Path=/
```

### Deleting cookies

To delete a cookie, send a `Set-Cookie` with `Max-Age=0`:

```alexscript
odp.usun_ciasteczko("session_id")
```

This is equivalent to `odp.ustaw_ciasteczko("session_id", "", { "max_age": 0, "path": "/" })`. Browsers treat `Max-Age=0` as immediate expiry.

### Cookie attributes worth knowing

**`HttpOnly`** — JavaScript on the page cannot read the cookie. Strongly recommended for session cookies to prevent XSS theft.

**`Secure`** — cookie is only sent over HTTPS. Set this in production.

**`SameSite`**:
- `Strict` — cookie not sent on cross-site requests at all (including following links from other sites). Maximum security but can break login flows from email links.
- `Lax` — cookie sent on top-level navigation but not in iframes or AJAX from other sites. Sensible default.
- `None` — cookie sent everywhere. Requires `Secure`.

For session cookies, use `Lax` unless you have specific reasons otherwise.

## Sessions

The session API gives you a per-client key-value store that survives across requests, with cryptographic protection against tampering.

### Mounting the middleware

```alexscript
niech sekret = "your-secret-key-keep-this-private-and-long"
serwer.middleware(Zubr::Middleware::Sesja::standardowa(sekret))
```

The secret is used to sign session IDs with HMAC-SHA256. Keep it stable across server restarts (otherwise existing sessions become invalid). For production, load it from an environment variable or config file — never commit it to source control.

### Configurable variant

For non-default cookie name or session lifetime:

```alexscript
serwer.middleware(Zubr::Middleware::Sesja::konfigurowalna(
  sekret,
  "_my_app_session",  # cookie name
  7200                 # max age in seconds (2 hours)
))
```

Default values from `standardowa`:
- Cookie name: `_zubr_sesja`
- Max age: 86400 seconds (24 hours)

### Using sessions in handlers

After the middleware is mounted, every request has a session:

```alexscript
serwer.get("/whoami", fn(zad) {
  niech s = zad.sesja()
  niech imie = s.pobierz("imie")
  jesli imie == nic {
    zwroc Zubr::Odpowiedz.tekst(200, "Anonymous\n")
  }
  zwroc Zubr::Odpowiedz.tekst(200, "Hi, " + imie + "!\n")
})
```

### The `Sesja` API

```alexscript
sesja.pobierz(klucz)         # value, or nic if absent
sesja.ustaw(klucz, wartosc)  # set value, mark dirty
sesja.usun(klucz)            # remove key, mark dirty
sesja.zniszcz()              # destroy entire session
sesja.identyfikator()        # the session ID (long random string)
sesja.dane()                 # full data hash (read-only — modifications won't trigger save)
```

### Login pattern

```alexscript
serwer.post("/login", fn(zad) {
  niech dane = zad.dane()
  niech email = dane["email"]
  niech haslo = dane["haslo"]

  niech uzytkownik = uwierzytelnij(email, haslo)
  jesli uzytkownik == nic {
    zwroc Zubr::Odpowiedz.json(401, { "error": "invalid credentials" })
  }

  niech s = zad.sesja()
  s.ustaw("user_id", uzytkownik["id"])
  s.ustaw("rola", uzytkownik["rola"])

  zwroc Zubr::Odpowiedz.json(200, {
    "logged_in": prawda,
    "name": uzytkownik["imie"]
  })
})
```

### Logout pattern

```alexscript
serwer.post("/logout", fn(zad) {
  zad.sesja().zniszcz()
  zwroc Zubr::Odpowiedz.json(200, { "logged_out": prawda })
})
```

`zniszcz()` removes the session from the server-side store and sends a `Set-Cookie` with `Max-Age=0` to remove it from the browser.

### Auth check pattern

```alexscript
funkcja wymagaj_loginu() {
  zwroc fn(zad, dalej) {
    niech s = zad.sesja()
    jesli s.pobierz("user_id") == nic {
      zwroc Zubr::Odpowiedz.json(401, { "error": "login required" })
    }
    zwroc dalej(zad)
  }
}

# Apply to specific routes by checking inside middleware, or wrap individual handlers:
serwer.get("/me", fn(zad) {
  niech user_id = zad.sesja().pobierz("user_id")
  jesli user_id == nic {
    zwroc Zubr::Odpowiedz.json(401, { "error": "login required" })
  }
  zwroc Zubr::Odpowiedz.json(200, znajdz_uzytkownika(user_id))
})
```

## How signed sessions work

The session cookie value has the format `<id>.<signature>` where:

- `id` is a 48-character random hex string (`SecureRandom.hex(24)`)
- `signature` is `Digest.hmac_sha256(secret, id)` — 64 characters of hex

When a request comes in:

1. Read the cookie. If absent or empty, create a fresh empty session in memory (not yet persisted).
2. Parse `id.signature`. If malformed, create a fresh session.
3. Compute the expected signature. Compare with the supplied signature using `Digest.porownaj` (constant-time, resistant to timing attacks).
4. If signatures match, look up `id` in the in-memory store. If missing, create a fresh session (it expired or never existed). If present, load its data.

When the response is sent:

1. If the session is destroyed, remove from the store and send `Max-Age=0` cookie.
2. If the session is dirty (any `ustaw` or `usun` was called), write to the store and send a fresh `Set-Cookie` with the signed cookie value.
3. If neither — no change to the cookie, no store write. (This is why a fresh visit with no session activity doesn't get a cookie.)

### Why this is secure

A client cannot forge a valid `id.signature` pair without knowing the secret. They can:
- Try to guess a session ID — astronomically unlikely (192 bits of entropy)
- Try to forge a signature — requires breaking HMAC-SHA256

They cannot:
- Read existing sessions (the data is server-side, not in the cookie)
- Tamper with their own session data (it's identified by ID, not stored client-side)

### Limitations

The session store is **in-memory and per-process**. Restart = all sessions gone. Multi-process deployments don't share sessions.

There's **no automatic cleanup** of expired sessions in the store. The store grows over time. For long-running deployments, sessions of inactive users accumulate. For MVP this is acceptable — production would want a periodic sweep.

The store is shared across threads. AlexScript hashes are not formally thread-safe, but Ruby's hash semantics make most operations safe in practice (lost writes are theoretically possible but unlikely to manifest).

### When NOT to use signed sessions

For very large session payloads (megabytes), in-memory storage doesn't scale. Externalize to Redis, Memcached, or a database — but Zubr doesn't ship with such a backend, you'd need to write one.

For sessions that need to survive process restarts, persist `_SESJA_STORE` to a JSON file periodically. This isn't built-in but is a small extension to write.

For zero-trust scenarios where the secret might leak, use shorter session lifetimes and rotate the secret. (Rotating invalidates all existing sessions.)