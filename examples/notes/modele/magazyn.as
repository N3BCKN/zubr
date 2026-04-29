import("plik")
import("json")
import("czas")

modul App {
  modul Modele {

    klasa Magazyn {
      funkcja konstruktor(sciezka_danych) {
        niech @sciezka = sciezka_danych
        niech @uzytkownicy = {}        # email_lower → Uzytkownik
        niech @uzytkownicy_po_id = {}  # id → Uzytkownik
        niech @notatki = {}            # id → Notatka
        niech @brudny = falsz
      }

      #  User CRUD 

      funkcja dodaj_uzytkownika(uzytkownik) {
        niech email_klucz = uzytkownik.email().malymi()
        @uzytkownicy[email_klucz] = uzytkownik
        @uzytkownicy_po_id[uzytkownik.identyfikator()] = uzytkownik
        sam.oznacz_brudny()
        zwroc uzytkownik
      }

      funkcja znajdz_uzytkownika_po_email(email) {
        zwroc @uzytkownicy[email.malymi()]
      }

      funkcja znajdz_uzytkownika_po_id(id) {
        zwroc @uzytkownicy_po_id[id]
      }

      funkcja czy_email_zajety(email) {
        zwroc @uzytkownicy[email.malymi()] != nic
      }

      #  Note CRUD 

      funkcja dodaj_notatke(notatka) {
        @notatki[notatka.identyfikator()] = notatka
        sam.oznacz_brudny()
        zwroc notatka
      }

      funkcja znajdz_notatke(id) {
        zwroc @notatki[id]
      }

      funkcja aktualizuj_notatke(notatka) {
        @notatki[notatka.identyfikator()] = notatka
        sam.oznacz_brudny()
        zwroc notatka
      }

      funkcja usun_notatke(id) {
        niech n = @notatki[id]
        @notatki[id] = nic
        jesli n != nic to sam.oznacz_brudny()
        zwroc n
      }

      #  Queries 

      # Returns notes belonging to user_id, optionally filtered by query and tag,
      # sorted by zmodyfikowana descending.
      funkcja notatki_uzytkownika(uzytkownik_id, q, tag) {
        niech wynik = []
        niech klucze = Json.klucze(@notatki)

        dla niech k = 0; klucze.dlg(); 1 {
          niech n = @notatki[klucze[k]]
          jesli n == nic to nastepny
          jesli !n.czy_nalezy_do(uzytkownik_id) to nastepny
          jesli q != nic i q != "" {
            jesli !n.czy_pasuje_do_zapytania(q) to nastepny
          }
          jesli tag != nic i tag != "" {
            jesli !n.czy_ma_tag(tag) to nastepny
          }
          wynik << n
        }

        sam.sortuj_po_zmodyfikowanej(wynik)
        zwroc wynik
      }

      prywatna funkcja sortuj_po_zmodyfikowanej(arr) {
        niech n = arr.dlg()
        dla niech k = 0; n - 1; 1 {
          dla niech j = 0; n - k - 1; 1 {
            jesli arr[j].zmodyfikowana() < arr[j + 1].zmodyfikowana() {
              niech tmp = arr[j]
              arr[j] = arr[j + 1]
              arr[j + 1] = tmp
            }
          }
        }
      }

      #  Persistence 

      funkcja oznacz_brudny() {
        @brudny = prawda
      }

      funkcja czy_brudny() { zwroc @brudny }

      # Write to disk if there are unsaved changes.
      # Atomic: write to .tmp, then rename.
      funkcja zapisz() {
        jesli !@brudny to zwroc falsz

        niech dane = sam.serializuj()
        niech sciezka_tmp = @sciezka + ".tmp"

        proba {
          Plik.zapisz(sciezka_tmp, Json.generuj(dane))
          Plik.przesun(sciezka_tmp, @sciezka)
          @brudny = falsz
          zwroc prawda
        } zlap (e) {
          # On error, leave brudny=true so next call retries.
          zwroc falsz
        }
      }

      prywatna funkcja serializuj() {
        niech tablica_uzytkownikow = []
        niech klucze_u = Json.klucze(@uzytkownicy_po_id)
        dla niech k = 0; klucze_u.dlg(); 1 {
          niech u = @uzytkownicy_po_id[klucze_u[k]]
          jesli u != nic to tablica_uzytkownikow << u.do_hasha_pelnego()
        }

        niech tablica_notatek = []
        niech klucze_n = Json.klucze(@notatki)
        dla niech k = 0; klucze_n.dlg(); 1 {
          niech n = @notatki[klucze_n[k]]
          jesli n != nic to tablica_notatek << n.do_hasha()
        }

        zwroc {
          "wersja": 1,
          "zapisano": Czas.stempel(),
          "uzytkownicy": tablica_uzytkownikow,
          "notatki": tablica_notatek
        }
      }

      # Load from disk. Returns true on success, false if file doesn't exist
      # or is corrupted (in which case store stays empty).
      funkcja czytaj() {
        jesli !Plik.istnieje(@sciezka) to zwroc falsz

        proba {
          niech surowe = Plik.czytaj(@sciezka)
          niech dane = Json.parsuj(surowe)

          niech tab_u = dane["uzytkownicy"]
          jesli tab_u != nic {
            dla niech k = 0; tab_u.dlg(); 1 {
              niech u = App::Modele::Uzytkownik::z_hasha(tab_u[k])
              niech email_klucz = u.email().malymi()
              @uzytkownicy[email_klucz] = u
              @uzytkownicy_po_id[u.identyfikator()] = u
            }
          }

          niech tab_n = dane["notatki"]
          jesli tab_n != nic {
            dla niech k = 0; tab_n.dlg(); 1 {
              niech n = App::Modele::Notatka::z_hasha(tab_n[k])
              @notatki[n.identyfikator()] = n
            }
          }

          @brudny = falsz
          zwroc prawda
        } zlap (e) {
          zwroc falsz
        }
      }

      # ─── Stats (useful for debugging) 

      funkcja statystyki() {
        zwroc {
          "uzytkownikow": Json.klucze(@uzytkownicy_po_id).dlg(),
          "notatek": Json.klucze(@notatki).dlg(),
          "brudny": @brudny
        }
      }
    }

    # Singleton magazyn — initialized in main.as
    funkcja _init_magazyn(sciezka) {
      globalna niech _MAGAZYN = Magazyn.nowy(sciezka)
      _MAGAZYN.czytaj()
    }

    funkcja magazyn() {
      zwroc _MAGAZYN
    }
  }
}