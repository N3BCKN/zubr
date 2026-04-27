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

serwer.start()