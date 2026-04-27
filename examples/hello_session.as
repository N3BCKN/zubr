import("securerandom")
import("digest")
import("../lib/zubr")

# Create a static directory for testing.
proba {
  Plik.utworz_katalog("./public")
  Plik.zapisz("./public/index.html", "<h1>Strona statyczna</h1>")
  Plik.zapisz("./public/style.css", "body { background: #f0f0f0; }")
} zlap (_) {
}

# Sekret HMAC. W produkcji to ENV variable albo plik konfiguracyjny
niech SEKRET = "tajny-klucz-dla-tej-aplikacji-dlugi-i-losowy"

niech serwer = Zubr::Serwer.nowy(8080)

# Middleware chain — applied in registration order, outermost first
serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
serwer.middleware(Zubr::Middleware::RateLimit::na_ip(100, 60))

serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(Zubr::Middleware::Sesja::standardowa(SEKRET))

# Static files mounted at /public
serwer.pliki_statyczne("/public", "./public")

# Regular routes
serwer.get("/", fn(zad) {
  niech imie = zad.sesja().pobierz("imie")
  jesli imie == nic {
    zwroc Zubr::Odpowiedz.tekst(200, "Witaj, niezalogowany goscia!\n")
  }
  zwroc Zubr::Odpowiedz.tekst(200, "Witaj, " + imie + "!\n")
})

serwer.post("/login", fn(zad) {
  niech imie = zad.tresc()
  jesli imie == "" {
    zwroc Zubr::Odpowiedz.tekst(400, "Brak imienia w body\n")
  }
  niech s = zad.sesja()
  s.ustaw("imie", imie)
  s.ustaw("zalogowany", prawda)
  s.ustaw("od", Czas.stempel())

  zwroc Zubr::Odpowiedz.tekst(200, "Zalogowano jako " + imie + "\n")
})

serwer.post("/logout", fn(zad) {
  zad.sesja().zniszcz()
  zwroc Zubr::Odpowiedz.tekst(200, "Wylogowano\n")
})

serwer.get("/sesja", fn(zad) {
  niech s = zad.sesja()
  zwroc Zubr::Odpowiedz.json(200, {
    "id": s.identyfikator(),
    "dane": s.dane()
  })
})

serwer.post("/api/echo_json", fn(zad) {
  niech d = zad.dane()
  jesli d == nic to zwroc Zubr::Odpowiedz.tekst(400, "Brak body\n")
  zwroc Zubr::Odpowiedz.json(200, {
    "otrzymano": d,
    "typ_content": zad.naglowek("content-type")
  })
})

serwer.post("/api/formularz", fn(zad) {
  niech imie = zad.pole_lub("imie", "(brak)")
  niech wiek = zad.pole_lub("wiek", "(brak)")
  zwroc Zubr::Odpowiedz.tekst(200, "Imie: " + imie + ", Wiek: " + wiek + "\n")
})

serwer.post("/api/raw", fn(zad) {
  niech d = zad.dane()
  niech typ_d = "nieznany"
  jesli d != nic to typ_d = d.typ()
  zwroc Zubr::Odpowiedz.tekst(200,
    "Content-Type: " + zad.naglowek("content-type") + "\n" +
    "Typ sparsowany: " + typ_d + "\n" +
    "Raw: " + zad.tresc() + "\n"
  )
})

serwer.start()