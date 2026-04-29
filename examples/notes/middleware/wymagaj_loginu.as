modul App {
  modul AppMiddleware {

    # Wraps a handler so that requests without a valid session get 401.
    # Use like:
    #   serwer.get("/api/notatki", App::AppMiddleware::wymagaj_loginu(fn(zad) { ... }))
    funkcja wymagaj_loginu(handler) {
      zwroc fn(zad) {
        niech s = zad.sesja()
        niech uid = s.pobierz("uzytkownik_id")
        jesli uid == nic {
          zwroc Zubr::Odpowiedz.json(401, { "error": "wymagane_zalogowanie" })
        }
        zwroc handler(zad)
      }
    }
  }
}