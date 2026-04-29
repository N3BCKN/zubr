modul App {
  modul Trasy {
    modul Widoki {

      funkcja zarejestruj(serwer) {
        # Home page — SPA shell. Frontend JS will check session
        # via /auth/me and redirect if needed
        serwer.get("/", fn(zad) {
          zwroc Zubr::Odpowiedz.plik("./public/index.html")
        })

        serwer.get("/login", fn(zad) {
          zwroc Zubr::Odpowiedz.plik("./public/login.html")
        })

        serwer.get("/rejestracja", fn(zad) {
          zwroc Zubr::Odpowiedz.plik("./public/rejestracja.html")
        })
      }
    }
  }
}