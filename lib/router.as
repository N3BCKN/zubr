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
        niech rzeczywista_m = metoda
        jesli metoda == "HEAD" to rzeczywista_m = "GET"
        jesli rzeczywista_m != @metoda i @metoda != "*" to zwroc nic
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
        niech metoda_oryg = zad.metoda()
        niech metoda_lookup = metoda_oryg
        jesli metoda_oryg == "HEAD" to metoda_lookup = "GET"
        niech sciezka = zad.sciezka()

        niech odp = nic

        # Try static routes first — O(1) hash lookup.
        niech klucz = metoda_lookup + " " + sciezka
        niech stat = @statyczne[klucz]
        jesli stat != nic {
          zad.ustaw_parametry({})
          odp = stat.handler()(zad)
        }

        # Then parametric routes, in registration order.
        jesli odp == nic {
          dla niech k = 0; @parametryczne.dlg(); 1 {
            niech t = @parametryczne[k]
            niech parametry = t.dopasuj(metoda_lookup, sciezka)
            jesli parametry != nic {
              zad.ustaw_parametry(parametry)
              odp = t.handler()(zad)
              zakoncz
            }
          }
        }

        # Then regex routes.
        jesli odp == nic {
          dla niech k = 0; @regex_trasy.dlg(); 1 {
            niech t = @regex_trasy[k]
            niech parametry = t.dopasuj(metoda_lookup, sciezka)
            jesli parametry != nic {
              zad.ustaw_parametry(parametry)
              odp = t.handler()(zad)
              zakoncz
            }
          }
        }

        # Match found — strip body for HEAD before returning.
        jesli odp != nic {
          jesli metoda_oryg == "HEAD" to odp.ustaw_tresc("")
          zwroc odp
        }

        # No match — check if path exists for other methods (405).
        niech inne_metody = znajdz_metody_dla_sciezki(sciezka)
        jesli inne_metody.dlg() > 0 {
          niech odp_405 = Zubr::Odpowiedz.tekst(405, "Method Not Allowed")
          odp_405.naglowek("Allow", polacz_metody(inne_metody))
          zwroc odp_405
        }

        # Standard 404.
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

      prywatna funkcja znajdz_metody_dla_sciezki(sciezka) {
        niech metody = []

        # Sprawdź statyczne — iteruj po kluczach hasha.
        niech klucze = Json.klucze(@statyczne)
        dla niech k = 0; klucze.dlg(); 1 {
          niech kl = klucze[k]
          niech parts = kl.rozdziel(" ")
          jesli parts.dlg() >= 2 i parts[1] == sciezka {
            metody << parts[0]
          }
        }
        zwroc metody
      }

      prywatna funkcja polacz_metody(lista) {
        jesli lista.dlg() == 0 to zwroc ""
        niech wynik = lista[0]
        dla niech k = 1; lista.dlg(); 1 {
          wynik = wynik + ", " + lista[k]
        }
        zwroc wynik
      }
    }
  }
}