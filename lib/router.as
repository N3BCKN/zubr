import("./response")

modul Zubr {
  modul Router {

    klasa Trasa {
      funkcja konstruktor(metoda, wzor, handler) {
        niech @metoda = metoda.duzymi()
        niech @wzor = wzor
        niech @handler = handler
        niech @nazwy = []
        niech @regex = kompiluj_wzor(wzor)
        niech @czy_statyczna = !wzor.zawiera(":") i !wzor.zawiera("*")
      }

      funkcja metoda() { zwroc @metoda }
      funkcja wzor() { zwroc @wzor }
      funkcja handler() { zwroc @handler }
      funkcja czy_statyczna() { zwroc @czy_statyczna }

      # Returns parametry hash on match, nic on miss.
      funkcja dopasuj(metoda, sciezka) {
        jesli metoda != @metoda i @metoda != "*" to zwroc nic

        jesli @czy_statyczna {
          jesli sciezka == @wzor to zwroc {}
          zwroc nic
        }

        niech d = @regex.dopasuj(sciezka)
        jesli d == nic to zwroc nic

        niech parametry = {}
        dla niech k = 0; @nazwy.dlg(); 1 {
          parametry[@nazwy[k]] = d.grupa(k + 1)
        }
        zwroc parametry
      }

      # Translate /users/:id/posts/:post_id → ^/users/([^/]+)/posts/([^/]+)$
      # Translate /static/* → ^/static/(.*)$
      # Stores parameter names for binding after match.
      prywatna funkcja kompiluj_wzor(wzor) {
        niech segmenty = wzor.rozdziel("/")
        niech wynik = "^"
        niech licznik_gwiazdek = 0

        dla niech k = 0; segmenty.dlg(); 1 {
          niech seg = segmenty[k]
          jesli k > 0 to wynik = wynik + "/"

          jesli seg == "" {
            # leading slash, nothing to add
          } albojesli seg.zawiera(":") {
            # :name → ([^/]+), record name
            niech nazwa = seg.wydziel(1, seg.dlg() - 1)
            @nazwy << nazwa
            wynik = wynik + "([^/]+)"
          } albojesli seg == "*" {
            licznik_gwiazdek = licznik_gwiazdek + 1
            niech nazwa = "wildcard"
            jesli licznik_gwiazdek > 1 to nazwa = "wildcard" + licznik_gwiazdek.napis()
            @nazwy << nazwa
            wynik = wynik + "(.*)"
          } albo {
            wynik = wynik + escapuj_segment(seg)
          }
        }

        wynik = wynik + "$"
        zwroc Wyrazenie.nowy(wynik)
      }

      prywatna funkcja escapuj_segment(seg) {
        zwroc Wyrazenie.escapuj(seg)
      }
    }

    klasa TrasaRegex {
      funkcja konstruktor(metoda, regex, handler) {
        niech @metoda = metoda.duzymi()
        niech @regex = regex
        niech @handler = handler
      }

      funkcja metoda() { zwroc @metoda }
      funkcja handler() { zwroc @handler }
      funkcja czy_statyczna() { zwroc falsz }

      funkcja dopasuj(metoda, sciezka) {
        jesli metoda != @metoda i @metoda != "*" to zwroc nic

        niech d = @regex.dopasuj(sciezka)
        jesli d == nic to zwroc nic

        niech parametry = {}
        # Expose named captures from the regex.
        proba {
          niech nazwane = d.nazwane()
          parametry = nazwane
        } zlap (_) {
        }

        zwroc parametry
      }
    }

    klasa SilnikRoutingu {
      funkcja konstruktor() {
        niech @statyczne = {}
        niech @parametryczne = []
        niech @regex_trasy = []
        niech @handler_404 = nic
      }

      funkcja dodaj(metoda, wzor, handler) {
        niech t = Trasa.nowy(metoda, wzor, handler)
        jesli t.czy_statyczna() {
          niech klucz = t.metoda() + " " + wzor
          @statyczne[klucz] = t
        } albo {
          @parametryczne << t
        }
        zwroc sam
      }

      funkcja dodaj_regex(metoda, regex, handler) {
        @regex_trasy << TrasaRegex.nowy(metoda, regex, handler)
        zwroc sam
      }

      funkcja ustaw_404(handler) {
        @handler_404 = handler
        zwroc sam
      }

      # Returns Odpowiedz. Never returns nic.
      funkcja dispatch(zad) {
        niech metoda = zad.metoda()
        niech sciezka = zad.sciezka()

        # Try static routes first — O(1) hash lookup.
        niech klucz = metoda + " " + sciezka
        niech stat = @statyczne[klucz]
        jesli stat != nic {
          zad.ustaw_parametry({})
          zwroc stat.handler()(zad)
        }

        # Then parametric routes, in registration order.
        dla niech k = 0; @parametryczne.dlg(); 1 {
          niech t = @parametryczne[k]
          niech parametry = t.dopasuj(metoda, sciezka)
          jesli parametry != nic {
            zad.ustaw_parametry(parametry)
            zwroc t.handler()(zad)
          }
        }

        # Then regex routes.
        dla niech k = 0; @regex_trasy.dlg(); 1 {
          niech t = @regex_trasy[k]
          niech parametry = t.dopasuj(metoda, sciezka)
          jesli parametry != nic {
            zad.ustaw_parametry(parametry)
            zwroc t.handler()(zad)
          }
        }

        # No match — call user 404 or default.
        jesli @handler_404 != nic {
          niech h = @handler_404
          zwroc h(zad)
        }
        zwroc Zubr::Odpowiedz.tekst(404, "Not Found")
      }

      # Method-Not-Allowed check — for diagnostics, optional.
      funkcja czy_sciezka_istnieje(sciezka) {
        niech klucze = Json.klucze(@statyczne)
        dla niech k = 0; klucze.dlg(); 1 {
          niech kl = klucze[k]
          niech parts = kl.rozdziel(" ")
          jesli parts.dlg() >= 2 i parts[1] == sciezka to zwroc prawda
        }
        zwroc falsz
      }
    }
  }
}