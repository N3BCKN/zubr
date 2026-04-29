# Tutorial: Build Your First Zubr API

This tutorial walks you through building a small task-tracking API. By the end you'll have a Zubr server with routing, request parsing, JSON responses, sessions, and a static frontend — about 100 lines of AlexScript total.

If you just want to see a complete working example, jump to the [Final code](#final-code) section at the bottom.

## Prerequisites

- AlexScript installed (`alexscript --version` should work)
- A copy of Zubr somewhere on your machine (the `zubr/` directory)
- `curl` for testing

## Step 1: Hello world

Create a new file `tasks/main.as`:

```alexscript
import("../zubr/lib/zubr")

niech serwer = Zubr::Serwer.nowy(8080)

serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Task tracker is running!\n")
})

serwer.start()
```

Run it:

```bash
alexscript tasks/main.as
```

You should see:

```
[zubr] 12:00:00 INFO Zubr listening on 0.0.0.0:8080
```

In another terminal:

```bash
curl http://127.0.0.1:8080/
# → Task tracker is running!
```

What just happened:

- `Zubr::Serwer.nowy(8080)` creates a server bound to port 8080
- `serwer.get(path, handler)` registers a route. The handler receives a `zad` (request) and returns an `Odpowiedz` (response)
- `Odpowiedz.tekst(status, body)` is one of several response factories — others include `.json`, `.html`, `.plik`, `.przekieruj`
- `serwer.start()` blocks the main thread, accepting connections and spawning a worker thread per client

## Step 2: A real route with parameters

Let's add an endpoint that echoes a task ID:

```alexscript
serwer.get("/tasks/:id", fn(zad) {
  niech id = zad.parametry()["id"]
  zwroc Zubr::Odpowiedz.json(200, {
    "task_id": id,
    "status": "pending"
  })
})
```

Restart the server and test:

```bash
curl http://127.0.0.1:8080/tasks/42
# → {"task_id":"42","status":"pending"}
```

The `:id` segment becomes a named parameter. Multiple parameters work too: `/users/:user_id/tasks/:task_id` would give you both in `zad.parametry()`.

## Step 3: In-memory task store

Real tasks need to be stored somewhere. We'll use a simple class for our in-memory store:

```alexscript
klasa Magazyn {
  funkcja konstruktor() {
    niech @zadania = {}
    niech @nastepne_id = 1
  }

  funkcja dodaj(tytul) {
    niech id = @nastepne_id.napis()
    @nastepne_id = @nastepne_id + 1

    niech zadanie = {
      "id": id,
      "tytul": tytul,
      "ukonczone": falsz,
      "utworzone": Czas.stempel()
    }
    @zadania[id] = zadanie
    zwroc zadanie
  }

  funkcja wszystkie() {
    niech wynik = []
    niech klucze = Json.klucze(@zadania)
    dla niech k = 0; klucze.dlg(); 1 {
      wynik << @zadania[klucze[k]]
    }
    zwroc wynik
  }

  funkcja znajdz(id) {
    zwroc @zadania[id]
  }

  funkcja oznacz_ukonczone(id) {
    niech z = @zadania[id]
    jesli z == nic to zwroc nic
    z["ukonczone"] = prawda
    zwroc z
  }

  funkcja usun(id) {
    niech z = @zadania[id]
    @zadania[id] = nic
    zwroc z
  }
}

niech magazyn = Magazyn.nowy()
```

Place this above your route definitions in `main.as`.

**A note on threading**: each connection runs in its own Ruby thread, so multiple handlers can run simultaneously. The `magazyn` hash is shared across threads. AlexScript hashes are not formally thread-safe, but for short critical sections (single read or write) the race window is tiny in practice. For production, you'd add explicit synchronization. For a tutorial, we won't.

## Step 4: REST endpoints

Now wire up the CRUD routes:

```alexscript
serwer.get("/tasks", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, magazyn.wszystkie())
})

serwer.post("/tasks", fn(zad) {
  niech dane = zad.dane()
  jesli dane == nic {
    zwroc Zubr::Odpowiedz.json(400, { "error": "missing body" })
  }

  niech tytul = dane["tytul"]
  jesli tytul == nic lub tytul == "" {
    zwroc Zubr::Odpowiedz.json(400, { "error": "tytul is required" })
  }

  niech zadanie = magazyn.dodaj(tytul)
  zwroc Zubr::Odpowiedz.json(201, zadanie)
})

serwer.get("/tasks/:id", fn(zad) {
  niech z = magazyn.znajdz(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, z)
})

serwer.put("/tasks/:id/done", fn(zad) {
  niech z = magazyn.oznacz_ukonczone(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, z)
})

serwer.delete("/tasks/:id", fn(zad) {
  niech z = magazyn.usun(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, { "deleted": z })
})
```

Note `zad.dane()` — this auto-parses the request body based on `Content-Type`. JSON becomes a hash, `application/x-www-form-urlencoded` becomes a hash of fields, anything else returns the raw string.

Test the full lifecycle:

```bash
# Create a task
curl -X POST -H "Content-Type: application/json" \
  -d '{"tytul":"Buy milk"}' http://127.0.0.1:8080/tasks
# → {"id":"1","tytul":"Buy milk","ukonczone":false,"utworzone":1714000000}

curl -X POST -H "Content-Type: application/json" \
  -d '{"tytul":"Walk the dog"}' http://127.0.0.1:8080/tasks
# → {"id":"2",...}

# List
curl http://127.0.0.1:8080/tasks
# → [{...},{...}]

# Mark done
curl -X PUT http://127.0.0.1:8080/tasks/1/done
# → {"id":"1","tytul":"Buy milk","ukonczone":true,...}

# Delete
curl -X DELETE http://127.0.0.1:8080/tasks/2
# → {"deleted":{...}}
```

## Step 5: Add request logging

Right now the server is silent during requests. Add the standard log middleware:

```alexscript
serwer.middleware(Zubr::Middleware::Log::standardowy())
```

Place this **before** any route definitions. Restart and watch the terminal:

```
[12:30:15] GET /tasks -> 200 1.2ms
[12:30:18] POST /tasks -> 201 2.1ms
[12:30:22] PUT /tasks/1/done -> 200 0.8ms
```

Middleware runs around every handler, before the response is sent. Multiple middleware compose — the **last** one registered runs **innermost** (closest to the handler), the first runs outermost.

## Step 6: Add CORS for browser clients

If you're building a single-page frontend that calls this API, you need CORS:

```alexscript
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
```

This adds `Access-Control-Allow-Origin: *` to every response and handles `OPTIONS` preflight requests automatically. For production, replace `"*"` with an array of allowed origins:

```alexscript
serwer.middleware(Zubr::Middleware::CORS::pozwol([
  "https://myapp.com",
  "https://www.myapp.com"
]))
```

## Step 7: Add a session for "current user"

Let's say we want each browser to have a unique user ID. Add session middleware:

```alexscript
niech sekret = "change-me-in-production-please-and-make-this-long"
serwer.middleware(Zubr::Middleware::Sesja::standardowa(sekret))
```

Now in any handler:

```alexscript
serwer.get("/whoami", fn(zad) {
  niech s = zad.sesja()
  niech imie = s.pobierz("imie")
  jesli imie == nic to zwroc Zubr::Odpowiedz.tekst(200, "Anonymous\n")
  zwroc Zubr::Odpowiedz.tekst(200, "Hi, " + imie + "!\n")
})

serwer.post("/login", fn(zad) {
  niech imie = zad.tresc()
  zad.sesja().ustaw("imie", imie)
  zwroc Zubr::Odpowiedz.tekst(200, "Welcome, " + imie + "\n")
})

serwer.post("/logout", fn(zad) {
  zad.sesja().zniszcz()
  zwroc Zubr::Odpowiedz.tekst(200, "Bye\n")
})
```

Test:

```bash
curl -c /tmp/c.txt http://127.0.0.1:8080/whoami
# → Anonymous

curl -c /tmp/c.txt -b /tmp/c.txt -X POST -d "Anna" http://127.0.0.1:8080/login
# → Welcome, Anna

curl -b /tmp/c.txt http://127.0.0.1:8080/whoami
# → Hi, Anna!
```

The session cookie is signed with HMAC-SHA256 using your secret. Tampering with it server-side is impossible without knowing the secret.

## Step 8: Serve a frontend

Create `tasks/public/index.html`:

```html
<!DOCTYPE html>
<html>
<head><title>Tasks</title></head>
<body>
<h1>My tasks</h1>
<ul id="list"></ul>
<form id="form">
  <input id="title" placeholder="New task" required>
  <button>Add</button>
</form>
<script>
async function refresh() {
  const tasks = await (await fetch('/tasks')).json();
  document.getElementById('list').innerHTML = tasks
    .map(t => `<li>${t.tytul}${t.ukonczone ? ' ✓' : ''}</li>`)
    .join('');
}
document.getElementById('form').addEventListener('submit', async e => {
  e.preventDefault();
  const title = document.getElementById('title').value;
  await fetch('/tasks', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({tytul: title})
  });
  document.getElementById('title').value = '';
  refresh();
});
refresh();
</script>
</body>
</html>
```

Wire it up:

```alexscript
serwer.pliki_statyczne("/static", "./public")

serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.plik("./public/index.html")
})
```

Now `http://127.0.0.1:8080/` shows the UI, and `/static/anything.css` would serve from `./public/anything.css`. Path traversal attacks (`../../../etc/passwd`) are blocked automatically.

## Step 9: Rate limiting

Protect the API from runaway clients:

```alexscript
serwer.middleware(Zubr::Middleware::RateLimit::na_ip(60, 60))
```

That's 60 requests per 60 seconds per IP. Clients hitting the limit get `429 Too Many Requests` with a `Retry-After: 60` header. Successful requests get `X-RateLimit-Limit` and `X-RateLimit-Remaining` headers.

For benchmarking your own server, comment this line out — `ab` will hit the limit immediately.

## Final code

Putting it all together, `tasks/main.as`:

```alexscript
import("../zubr/lib/zubr")

klasa Magazyn {
  funkcja konstruktor() {
    niech @zadania = {}
    niech @nastepne_id = 1
  }

  funkcja dodaj(tytul) {
    niech id = @nastepne_id.napis()
    @nastepne_id = @nastepne_id + 1
    niech zadanie = {
      "id": id, "tytul": tytul, "ukonczone": falsz,
      "utworzone": Czas.stempel()
    }
    @zadania[id] = zadanie
    zwroc zadanie
  }

  funkcja wszystkie() {
    niech wynik = []
    niech klucze = Json.klucze(@zadania)
    dla niech k = 0; klucze.dlg(); 1 {
      wynik << @zadania[klucze[k]]
    }
    zwroc wynik
  }

  funkcja znajdz(id) { zwroc @zadania[id] }

  funkcja oznacz_ukonczone(id) {
    niech z = @zadania[id]
    jesli z == nic to zwroc nic
    z["ukonczone"] = prawda
    zwroc z
  }

  funkcja usun(id) {
    niech z = @zadania[id]
    @zadania[id] = nic
    zwroc z
  }
}

niech magazyn = Magazyn.nowy()
niech serwer = Zubr::Serwer.nowy(8080)

serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
serwer.middleware(Zubr::Middleware::Sesja::standardowa("change-me-please-make-this-long"))

serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.plik("./public/index.html")
})

serwer.pliki_statyczne("/static", "./public")

serwer.get("/tasks", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, magazyn.wszystkie())
})

serwer.post("/tasks", fn(zad) {
  niech dane = zad.dane()
  jesli dane == nic to zwroc Zubr::Odpowiedz.json(400, { "error": "missing body" })
  niech tytul = dane["tytul"]
  jesli tytul == nic lub tytul == "" {
    zwroc Zubr::Odpowiedz.json(400, { "error": "tytul required" })
  }
  zwroc Zubr::Odpowiedz.json(201, magazyn.dodaj(tytul))
})

serwer.get("/tasks/:id", fn(zad) {
  niech z = magazyn.znajdz(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, z)
})

serwer.put("/tasks/:id/done", fn(zad) {
  niech z = magazyn.oznacz_ukonczone(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, z)
})

serwer.delete("/tasks/:id", fn(zad) {
  niech z = magazyn.usun(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, { "deleted": z })
})

serwer.start()
```

 Run it, point your browser at `http://127.0.0.1:8080/`, and start adding tasks.