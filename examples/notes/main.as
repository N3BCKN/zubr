import("../../lib/zubr")

import("./config")
import("./modele/uzytkownik")
import("./modele/notatka")
import("./modele/magazyn")
import("./walidacja/wspolne")
import("./walidacja/uzytkownik")
import("./walidacja/notatka")
import("./middleware/wymagaj_loginu")
import("./trasy/auth")
import("./trasy/notatki")
import("./trasy/widoki")

# Initialize globals
App::Config::_init()
niech cfg = App::Config::config()

niech sciezka_danych = Plik.biezacy_katalog() + "/" + cfg.sciezka_danych()
App::Modele::_init_magazyn(sciezka_danych)

# Build server
niech serwer = Zubr::Serwer.nowy(cfg.port())
serwer.ustaw_host(cfg.host())

# Middleware order matters — outermost first, innermost last
serwer.middleware(Zubr::Middleware::Log::standardowy())
serwer.middleware(Zubr::Middleware::CORS::pozwol("*"))
serwer.middleware(Zubr::Middleware::RateLimit::na_ip(cfg.rate_limit_req(), cfg.rate_limit_okno()))
serwer.middleware(Zubr::Middleware::Sesja::standardowa(cfg.sekret_sesji()))

# Static assets
serwer.pliki_statyczne("/static", "./public")

# Routes — register each module's routes
App::Trasy::Widoki::zarejestruj(serwer)
App::Trasy::Auth::zarejestruj(serwer)
App::Trasy::Notatki::zarejestruj(serwer)

# Custom 404 — JSON for /api/*, HTML for everything else
serwer.trasa_404(fn(zad) {
  niech sciezka = zad.sciezka()
  niech jest_api = falsz
  jesli sciezka.dlg() >= 4 {
    niech prefix = sciezka.wycinek(0, 3)
    jesli prefix == "/api" to jest_api = prawda
  }

  jesli jest_api {
    zwroc Zubr::Odpowiedz.json(404, { "error": "nie_znaleziono", "sciezka": sciezka })
  }
  zwroc Zubr::Odpowiedz.tekst(404, "Strona nie znaleziona\n")
})

serwer.start()