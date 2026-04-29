# Zubr

> A micro-framework for building HTTP services in [AlexScript](https://github.com/alexscript) — Polish-syntax language, Sinatra-style API.

[![Status](https://img.shields.io/badge/status-beta-orange.svg)]()
[![Language](https://img.shields.io/badge/language-AlexScript-blue.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()

```alexscript
import("../lib/zubr")

niech serwer = Zubr::Serwer.nowy(8080)

serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Hello from Zubr!\n")
})

serwer.get("/users/:id", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, {
    "id": zad.parametry()["id"],
    "name": "Anna"
  })
})

serwer.start()
```

```bash
$ alexscript main.as
[zubr] 12:00:00 INFO Zubr listening on 0.0.0.0:8080

$ curl http://127.0.0.1:8080/
Hello from Zubr!

$ curl http://127.0.0.1:8080/users/42
{"id":"42","name":"Anna"}
```

## Features

- **HTTP/1.1 server** with keep-alive, configurable timeouts, graceful shutdown
- **Routing** — static, parametric (`/users/:id`), wildcard (`/static/*`), regex
- **Middleware chain** — composable pipeline with built-in logger, CORS, rate limiter, sessions
- **Request body parsing** — auto-dispatched by Content-Type (JSON, form-urlencoded, plain text)
- **Cookie API** — read/write with full attribute support (HttpOnly, Secure, SameSite, etc.)
- **Sessions** — HMAC-signed IDs, in-memory store, configurable cookie name and TTL
- **Static file serving** — ETag, Last-Modified, conditional GET (304), path traversal protection
- **Streaming responses** — constant memory regardless of file size
- **Content negotiation** — `Accept:` header parsing with q-values and type wildcards
- **Method handling** — automatic HEAD support, 405 with `Allow:` header

## Performance

Tested on a 2024 MacBook Pro:

| Workload | Throughput | p50 | p99 |
|---|---|---|---|
| Hello world, 10 connections | 2,150 req/s | 0.97ms | 354ms |
| Hello world, 50 connections | 1,590 req/s | 0.95ms | 1.39s |
| Routing + 3 middleware | 1,540 req/s | 1.2ms | 14ms |
| Static file 50MB, 10 concurrent | 1.97 GB/s | — | 282ms |
| Static file 50MB, sustained | constant ~100MB RSS | — | — |

Throughput is bounded primarily by the AlexScript interpreter and Ruby's GVL — see [Architecture](#architecture) for details.

## Installation

Zubr requires the AlexScript interpreter on `PATH`. No additional dependencies — Zubr uses only AlexScript's standard native libraries (socket, json, czas, digest, securerandom, plik, http).

```bash
git clone https://github.com/your-org/zubr.git
cd zubr
alexscript examples/hello.as
```

## Quick Start

Create `app/main.as`:

```alexscript
import("../lib/zubr")

niech serwer = Zubr::Serwer.nowy(8080)

# Middleware (outermost first)
serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))

# Routes
serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Hello\n")
})

serwer.post("/api/users", fn(zad) {
  niech dane = zad.dane()
  zwroc Zubr::Odpowiedz.json(201, {
    "created": prawda,
    "user": dane
  })
})

# Static files
serwer.pliki_statyczne("/static", "./public")

# Custom 404
serwer.trasa_404(fn(zad) {
  zwroc Zubr::Odpowiedz.json(404, { "error": "not_found" })
})

serwer.start()
```

Run from the app directory:

```bash
cd app
alexscript main.as
```

## Sessions in 5 lines

```alexscript
serwer.middleware(Zubr::Middleware::Sesja::standardowa("your-secret-key"))

serwer.post("/login", fn(zad) {
  zad.sesja().ustaw("user_id", 42)
  zwroc Zubr::Odpowiedz.tekst(200, "Logged in\n")
})

serwer.get("/me", fn(zad) {
  niech uid = zad.sesja().pobierz("user_id")
  jesli uid == nic to zwroc Zubr::Odpowiedz.tekst(401, "Login required\n")
  zwroc Zubr::Odpowiedz.tekst(200, "User " + uid.napis() + "\n")
})
```

Cookies are HMAC-signed with your secret. Tampering is impossible without the key.

## Project Structure

A typical Zubr application:

```
my-app/
├── main.as                  # entry point
├── modele/                  # data models
├── trasy/                   # route handlers (split by domain)
├── middleware/              # custom middleware
├── walidacja/               # input validators
└── public/                  # static assets (HTML, CSS, JS)
    └── index.html
```

For a full working example with auth, CRUD, persistence, and a vanilla-JS frontend, see [`examples/notes/`](examples/notes/).

## Documentation

Full reference documentation is in [`docs/`](docs/):

- **[Tutorial](docs/tutorial.md)** — Build your first API step by step
- **[Server API](docs/server.md)** — `Zubr::Serwer`, routing, lifecycle, configuration
- **[Request & Response](requestresponse.md)** — `Zadanie`, `Odpowiedz`, factories, content negotiation, streaming
- **[Middleware](docs/middleware.md)** — Built-in middleware and writing your own
- **[Sessions & Cookies](docs/cookies.md)** — Cookie API and signed sessions

## Architecture

Zubr is a tree of AlexScript modules:

```
zubr/
├── lib/
│   ├── zubr.as              # imports all submodules
│   ├── codes.as             # status codes, MIME types
│   ├── parser.as            # HTTP request parser
│   ├── response.as          # Odpowiedz class, content negotiation
│   ├── logger.as            # connection-level logger
│   ├── connection.as        # per-connection handler loop
│   ├── router.as            # routing engine
│   ├── middleware.as        # middleware chain builder
│   ├── static_files.as      # file serving with ETag
│   └── serwer.as            # main Serwer class
├── middleware/
│   ├── log.as               # request logger
│   ├── cors.as              # CORS handler
│   ├── rate_limit.as        # per-IP rate limiting
│   └── sesja.as             # signed session middleware
└── examples/
    ├── hello.as             # minimal example
    └── notes/               # full demo app (auth, CRUD, frontend)
```

The server uses **thread-per-connection** dispatch. Each accepted TCP connection runs in its own Ruby thread that parses the request, runs it through the middleware chain, and writes the response. This is simpler and more reliable than fiber-based async (which currently hits a Ruby fiber-scheduler bug under load) but bounds throughput by Ruby's GVL.

## Status

Zubr is in **beta**. The API is stable but the implementation is young. Tested in development and small production-like workloads — the [`examples/notes/`](examples/notes/) demo runs reliably under sustained load with multi-user data isolation.

If you find a bug, please open an issue with a minimal reproducer.

## Contributing

Contributions welcome. Areas where help is especially appreciated:

- Multipart/form-data parser
- WebSocket support
- Persistent session backends (Redis, file, SQLite)
- Per-route middleware groups
- HTTPS via native TLS bindings
- More benchmarking under varied workloads

## License

MIT — see [LICENSE](LICENSE) for details.