import("../modele/notatka")
import("../modele/magazyn")
import("../walidacja/notatka")
import("../middleware/wymagaj_loginu")

modul App {
  modul Trasy {
    modul Notatki {

      funkcja zarejestruj(serwer) {
        serwer.get("/api/notatki",
          App::AppMiddleware::wymagaj_loginu(fn(zad) {
            zwroc obsluz_liste(zad)
          })
        )

        serwer.get("/api/notatki/:id",
          App::AppMiddleware::wymagaj_loginu(fn(zad) {
            zwroc obsluz_pobierz(zad)
          })
        )

        serwer.post("/api/notatki",
          App::AppMiddleware::wymagaj_loginu(fn(zad) {
            zwroc obsluz_utworz(zad)
          })
        )

        serwer.put("/api/notatki/:id",
          App::AppMiddleware::wymagaj_loginu(fn(zad) {
            zwroc obsluz_aktualizuj(zad)
          })
        )

        serwer.delete("/api/notatki/:id",
          App::AppMiddleware::wymagaj_loginu(fn(zad) {
            zwroc obsluz_usun(zad)
          })
        )
      }

      prywatna funkcja obsluz_liste(zad) {
        niech uid = zad.sesja().pobierz("uzytkownik_id")

        niech q = zad.zapytanie()["q"]
        niech tag = zad.zapytanie()["tag"]
        jesli q == nic to q = ""
        jesli tag == nic to tag = ""

        niech mag = App::Modele::magazyn()

        niech notatki = mag.notatki_uzytkownika(uid, q, tag)
        niech tablica = []
        dla niech k = 0; notatki.dlg(); 1 {
          niech n = notatki[k]
          niech h = n.do_hasha()
          tablica << h
        }

        niech odp = {
          "notatki": tablica,
          "liczba": tablica.dlg()
        }
        zwroc Zubr::Odpowiedz.json(200, odp)
      }

      prywatna funkcja obsluz_pobierz(zad) {
        niech uid = zad.sesja().pobierz("uzytkownik_id")
        niech id = zad.parametry()["id"]
        niech mag = App::Modele::magazyn()
        niech n = mag.znajdz_notatke(id)

        jesli n == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "nie_znaleziono" })

        # Authorization: only the owner can read their note
        # Important — use 404 (not 403) to avoid leaking note existence to other users
        jesli !n.czy_nalezy_do(uid) to zwroc Zubr::Odpowiedz.json(404, { "error": "nie_znaleziono" })

        zwroc Zubr::Odpowiedz.json(200, n.do_hasha())
      }

      prywatna funkcja obsluz_utworz(zad) {
        niech uid = zad.sesja().pobierz("uzytkownik_id")
        niech dane = zad.dane()

        # Default tagi to empty array if not provided
        jesli dane != nic i dane["tagi"] == nic to dane["tagi"] = []

        niech bledy = App::Walidacja::Notatka::utworz(dane)
        jesli bledy.dlg() > 0 {
          zwroc Zubr::Odpowiedz.json(400, { "bledy": bledy })
        }

        niech tytul = dane["tytul"]
        niech tresc = dane["tresc"]
        jesli tresc == nic to tresc = ""
        niech tagi = dane["tagi"]

        niech nowa = App::Modele::Notatka::utworz(uid, tytul, tresc, tagi)

        niech mag = App::Modele::magazyn()
        mag.dodaj_notatke(nowa)
        mag.zapisz()

        zwroc Zubr::Odpowiedz.json(201, nowa.do_hasha())
      }

      prywatna funkcja obsluz_aktualizuj(zad) {
        niech uid = zad.sesja().pobierz("uzytkownik_id")
        niech id = zad.parametry()["id"]
        niech mag = App::Modele::magazyn()
        niech n = mag.znajdz_notatke(id)

        jesli n == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "nie_znaleziono" })
        jesli !n.czy_nalezy_do(uid) to zwroc Zubr::Odpowiedz.json(404, { "error": "nie_znaleziono" })

        niech dane = zad.dane()
        jesli dane != nic i dane["tagi"] == nic to dane["tagi"] = []

        niech bledy = App::Walidacja::Notatka::aktualizuj(dane)
        jesli bledy.dlg() > 0 {
          zwroc Zubr::Odpowiedz.json(400, { "bledy": bledy })
        }

        niech tresc = dane["tresc"]
        jesli tresc == nic to tresc = ""

        n.aktualizuj(dane["tytul"], tresc, dane["tagi"])
        mag.aktualizuj_notatke(n)
        mag.zapisz()

        zwroc Zubr::Odpowiedz.json(200, n.do_hasha())
      }

      prywatna funkcja obsluz_usun(zad) {
        niech uid = zad.sesja().pobierz("uzytkownik_id")
        niech id = zad.parametry()["id"]
        niech mag = App::Modele::magazyn()
        niech n = mag.znajdz_notatke(id)

        jesli n == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "nie_znaleziono" })
        jesli !n.czy_nalezy_do(uid) to zwroc Zubr::Odpowiedz.json(404, { "error": "nie_znaleziono" })

        mag.usun_notatke(id)
        mag.zapisz()
        zwroc Zubr::Odpowiedz.brak_zawartosci()
      }
    }
  }
}