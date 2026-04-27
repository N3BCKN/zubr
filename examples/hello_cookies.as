import("securerandom")
import("../lib/zubr")

# Create a static directory for testing.
proba {
  Plik.utworz_katalog("./public")
  Plik.zapisz("./public/index.html", "<h1>Strona statyczna</h1>")
  Plik.zapisz("./public/style.css", "body { background: #f0f0f0; }")
} zlap (_) {
}

niech serwer = Zubr::Serwer.nowy(8080)

# Middleware chain — applied in registration order, outermost first.
serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
serwer.middleware(Zubr::Middleware::RateLimit::na_ip(100, 60))

# Static files mounted at /public.
serwer.pliki_statyczne("/public", "./public")

# Regular routes.
serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Witaj w Zubrze!\n")
})

serwer.get("/users/:id", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, { "id": zad.parametry()["id"] })
})

serwer.post("/echo", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Odebrano: " + zad.tresc())
})

serwer.trasa_404(fn(zad) {
  zwroc Zubr::Odpowiedz.json(404, { "blad": "Nie znaleziono" })
})

serwer.get("/whoami", fn(zad) {
  niech sid = zad.ciasteczko("session_id")
  jesli sid == nic {
    zwroc Zubr::Odpowiedz.tekst(200, "Brak sesji\n")
  }
  zwroc Zubr::Odpowiedz.tekst(200, "Twoja sesja: " + sid + "\n")
})

serwer.get("/login", fn(zad) {
  niech sid = SecureRandom.hex(16)
  niech odp = Zubr::Odpowiedz.tekst(200, "Zalogowano! ID: " + sid + "\n")
  odp.ustaw_ciasteczko("session_id", sid, {
    "max_age": 3600,
    "http_only": prawda,
    "same_site": "Strict"
  })
  zwroc odp
})

serwer.get("/logout", fn(zad) {
  niech odp = Zubr::Odpowiedz.tekst(200, "Wylogowano\n")
  odp.usun_ciasteczko("session_id")
  zwroc odp
})

serwer.get("/preferencje", fn(zad) {
  niech tryb = zad.ciasteczko("tryb")
  jesli tryb == nic to tryb = "jasny"
  zwroc Zubr::Odpowiedz.tekst(200, "Tryb: " + tryb + "\n")
})

serwer.post("/preferencje", fn(zad) {
  niech nowy_tryb = zad.tresc()
  niech odp = Zubr::Odpowiedz.tekst(200, "Zapisano: " + nowy_tryb + "\n")
  odp.ustaw_ciasteczko("tryb", nowy_tryb, {
    "max_age": 86400,
    "path": "/"
  })
  zwroc odp
})

serwer.start()