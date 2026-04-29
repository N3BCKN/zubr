import("../modele/uzytkownik")
import("../modele/magazyn")
import("../walidacja/uzytkownik")

modul App {
  modul Trasy {
    modul Auth {

      funkcja zarejestruj(serwer) {
        serwer.post("/auth/register", fn(zad) {
          zwroc obsluz_rejestracje(zad)
        })

        serwer.post("/auth/login", fn(zad) {
          zwroc obsluz_login(zad)
        })

        serwer.post("/auth/logout", fn(zad) {
          zwroc obsluz_logout(zad)
        })

        serwer.get("/auth/me", fn(zad) {
          zwroc obsluz_me(zad)
        })
      }

      prywatna funkcja obsluz_rejestracje(zad) {
        niech dane = zad.dane()
        niech bledy = App::Walidacja::Uzytkownik::rejestracja(dane)
        jesli bledy.dlg() > 0 {
          zwroc Zubr::Odpowiedz.json(400, { "bledy": bledy })
        }

        niech mag = App::Modele::magazyn()
        niech email = dane["email"]
        # Email uniqueness check
        jesli mag.czy_email_zajety(email) {
          zwroc Zubr::Odpowiedz.json(409, {
            "bledy": [{ "pole": "email", "wiadomosc": "Email jest juz zajety" }]
          })
        }

        # Create user. Extract result first — interpreter quirk: nested calls
        # in arguments may double-evaluate
        niech nowy = App::Modele::Uzytkownik::utworz(email, dane["nazwa"], dane["haslo"])
        mag.dodaj_uzytkownika(nowy)
        mag.zapisz()

        # Auto-login after registration
        niech s = zad.sesja()
        s.ustaw("uzytkownik_id", nowy.identyfikator())

        niech publiczne = nowy.do_hasha_publicznego()
        zwroc Zubr::Odpowiedz.json(201, publiczne)
      }

      prywatna funkcja obsluz_login(zad) {
        niech dane = zad.dane()
        niech bledy = App::Walidacja::Uzytkownik::login(dane)
        jesli bledy.dlg() > 0 {
          zwroc Zubr::Odpowiedz.json(400, { "bledy": bledy })
        }

        niech mag = App::Modele::magazyn()
        niech uzytkownik = mag.znajdz_uzytkownika_po_email(dane["email"])

        jesli uzytkownik == nic {
          zwroc Zubr::Odpowiedz.json(401, {
            "bledy": [{ "pole": "_", "wiadomosc": "Niepoprawny email lub haslo" }]
          })
        }

        niech haslo_ok = uzytkownik.sprawdz_haslo(dane["haslo"])
        jesli !haslo_ok {
          zwroc Zubr::Odpowiedz.json(401, {
            "bledy": [{ "pole": "_", "wiadomosc": "Niepoprawny email lub haslo" }]
          })
        }

        niech s = zad.sesja()
        niech uid = uzytkownik.identyfikator()
        s.ustaw("uzytkownik_id", uid)

        niech publiczne = uzytkownik.do_hasha_publicznego()

        # Build response into a variable, return the variable.
        # Avoids having Odpowiedz.json(...) as the return expression — bug #3 may eval twice.
        niech odp = Zubr::Odpowiedz.json(200, publiczne)
        zwroc odp
      }

      prywatna funkcja obsluz_logout(zad) {
        niech s = zad.sesja()
        s.zniszcz()
        zwroc Zubr::Odpowiedz.json(200, { "wylogowano": prawda })
      }

      prywatna funkcja obsluz_me(zad) {
        niech s = zad.sesja()
        niech uid = s.pobierz("uzytkownik_id")
        jesli uid == nic {
          zwroc Zubr::Odpowiedz.json(401, { "error": "niezalogowany" })
        }

        niech mag = App::Modele::magazyn()
        niech uzytkownik = mag.znajdz_uzytkownika_po_id(uid)
        jesli uzytkownik == nic {
          # Session has user_id but user no longer exists — destroy session
          s.zniszcz()
          zwroc Zubr::Odpowiedz.json(401, { "error": "uzytkownik_nieistnieje" })
        }

        niech publiczne = uzytkownik.do_hasha_publicznego()
        zwroc Zubr::Odpowiedz.json(200, publiczne)
      }
    }
  }
}