import('http')
import('json')

modul Zubr {
  modul Parser {
    klasa Limity {
      funkcja konstruktor() {
        niech @max_request_line = 8192
        niech @max_naglowek_linia = 16384
        niech @max_naglowki = 100
        niech @max_cialo = 10485760
      }

      funkcja max_request_line() { zwroc @max_request_line }
      funkcja max_naglowek_linia() { zwroc @max_naglowek_linia }
      funkcja max_naglowki() { zwroc @max_naglowki }
      funkcja max_cialo() { zwroc @max_cialo }

      funkcja ustaw_max_cialo(n) {
        @max_cialo = n
        zwroc sam
      }
    }

    klasa Zadanie {
      funkcja konstruktor() {
        niech @metoda = ""
        niech @sciezka = ""
        niech @sciezka_surowa = ""
        niech @wersja = ""
        niech @zapytanie = {}
        niech @naglowki = {}
        niech @tresc = ""
        niech @parametry = {}
        niech @json_cache = nic
        niech @ciasteczka_cache = nic
        niech @sesja = nic
      }

      funkcja metoda() { zwroc @metoda }
      funkcja sciezka() { zwroc @sciezka }
      funkcja sciezka_surowa() { zwroc @sciezka_surowa }
      funkcja wersja() { zwroc @wersja }
      funkcja zapytanie() { zwroc @zapytanie }
      funkcja naglowki() { zwroc @naglowki }
      funkcja tresc() { zwroc @tresc }
      funkcja parametry() { zwroc @parametry }
      funkcja sesja() { zwroc @sesja }

      funkcja naglowek(nazwa) {
        zwroc @naglowki[nazwa.malymi()]
      }

      funkcja ustaw_sesja(s) {
        @sesja = s
        zwroc sam
      }

      funkcja ustaw_metoda(m) { 
        @metoda = m
        zwroc sam 
      }
      funkcja ustaw_sciezka(s) { 
        @sciezka = s
        zwroc sam 
      }
      funkcja ustaw_sciezka_surowa(s) { 
        @sciezka_surowa = s
        zwroc sam 
      }
      funkcja ustaw_wersja(v) { 
        @wersja = v
        zwroc sam 
      }
      funkcja ustaw_zapytanie(z) { 
        @zapytanie = z
        zwroc sam 
      }
      funkcja ustaw_naglowki(n) { 
        @naglowki = n
        zwroc sam 
      }
      funkcja ustaw_tresc(c) { 
        @tresc = c
        zwroc sam 
      }
      funkcja ustaw_parametry(p) { 
        @parametry = p
        zwroc sam 
      }

      funkcja czy_keep_alive() {
        niech c = sam.naglowek("connection")
        jesli c != nic {
          zwroc c.malymi() != "close"
        }
        zwroc @wersja == "HTTP/1.1"
      }

      funkcja json() {
        jesli @json_cache != nic to zwroc @json_cache
        niech ct = sam.naglowek("content-type")
        jesli ct == nic to rzuc BladWykonania.nowy("Brak Content-Type")
        jesli !ct.malymi().zawiera("application/json") to rzuc BladWykonania.nowy("Content-Type nie jest JSON")
        @json_cache = Json.parsuj(@tresc)
        zwroc @json_cache
      }

      # Lazy-parsed cookies. Returns hash, never nic.
      funkcja ciasteczka() {
        jesli @ciasteczka_cache != nic to zwroc @ciasteczka_cache
        niech header = sam.naglowek("cookie")
        jesli header == nic {
          @ciasteczka_cache = {}
          zwroc @ciasteczka_cache
        }
        @ciasteczka_cache = parsuj_ciasteczka(header)
        zwroc @ciasteczka_cache
      }

      funkcja ciasteczko(nazwa) {
        niech c = sam.ciasteczka()
        zwroc c[nazwa]
      }
    }

    klasa BladParsera < BladWykonania {
      funkcja konstruktor(status, wiadomosc) {
        super(wiadomosc)
        niech @status = status
      }
      funkcja status() { zwroc @status }
    }

    funkcja re_request_line() {
      zwroc Wyrazenie.nowy("^([A-Z]+) (\\S+) (HTTP/[0-9]\\.[0-9])$")
    }

    funkcja re_naglowek() {
      zwroc Wyrazenie.nowy("^([!-9;-~]+):[ \\t]*(.*?)[ \\t]*$")
    }

    funkcja re_sciezka_zapytanie() {
      zwroc Wyrazenie.nowy("^([^?]*)\\??(.*)$")
    }

    funkcja czytaj(socket, limity) {
      niech rl = socket.czytaj_linie()
      jesli rl == "" lub rl == nic to zwroc nic

      jesli rl.dlg() > limity.max_request_line() {
        rzuc BladParsera.nowy(414, "Request line too long")
      }

      niech d = re_request_line().dopasuj(rl)
      jesli d == nic to rzuc BladParsera.nowy(400, "Invalid request line")

      niech metoda = d.grupa(1)
      niech cel = d.grupa(2)
      niech wersja = d.grupa(3)

      jesli !Codes::czy_dozwolona_metoda(metoda) {
        rzuc BladParsera.nowy(501, "Method not implemented")
      }

      niech sp = rozdziel_sciezke_zapytanie(cel)
      niech sciezka = dekoduj_url(sp[0])
      niech zapytanie = parsuj_zapytanie(sp[1])

      niech naglowki = czytaj_naglowki(socket, limity)
      niech tresc = czytaj_tresc(socket, naglowki, limity, metoda)

      niech zad = Zadanie.nowy()
      zad.ustaw_metoda(metoda)
      zad.ustaw_sciezka(sciezka)
      zad.ustaw_sciezka_surowa(cel)
      zad.ustaw_wersja(wersja)
      zad.ustaw_zapytanie(zapytanie)
      zad.ustaw_naglowki(naglowki)
      zad.ustaw_tresc(tresc)

      zwroc zad
    }

    funkcja rozdziel_sciezke_zapytanie(cel) {
      niech d = re_sciezka_zapytanie().dopasuj(cel)
      jesli d == nic to zwroc [cel, ""]
      zwroc [d.grupa(1), d.grupa(2)]
    }

    funkcja parsuj_zapytanie(qs) {
      jesli qs == "" to zwroc {}
      zwroc Http.parsuj_zapytanie(qs)
    }

    funkcja dekoduj_url(s) {
      jesli !s.zawiera("%") {
        jesli !s.zawiera("+") to zwroc s
      }
      zwroc Http.dekoduj_url(s)
    }

    funkcja czytaj_naglowki(socket, limity) {
      niech naglowki = {}
      niech licznik = 0
      niech max_n = limity.max_naglowki()

      dopoki prawda {
        niech linia = socket.czytaj_linie()
        jesli linia == "" to zwroc naglowki
        jesli linia == nic to rzuc BladParsera.nowy(400, "Unexpected EOF in headers")

        jesli linia.dlg() > limity.max_naglowek_linia() {
          rzuc BladParsera.nowy(431, "Header line too long")
        }

        licznik = licznik + 1
        jesli licznik > max_n to rzuc BladParsera.nowy(431, "Too many headers")

        niech d = re_naglowek().dopasuj(linia)
        jesli d == nic to rzuc BladParsera.nowy(400, "Malformed header")

        niech klucz = d.grupa(1).malymi()
        niech wartosc = d.grupa(2)

        jesli naglowki[klucz] != nic {
          naglowki[klucz] = naglowki[klucz] + ", " + wartosc
        } albo {
          naglowki[klucz] = wartosc
        }
      }
    }

    funkcja czytaj_tresc(socket, naglowki, limity, metoda) {
      niech ma_tresc = metoda == "POST" lub metoda == "PUT" lub metoda == "PATCH"
      niech cl = naglowki["content-length"]
      niech te = naglowki["transfer-encoding"]

      jesli te != nic {
        jesli te.malymi().zawiera("chunked") {
          rzuc BladParsera.nowy(411, "Chunked transfer-encoding not supported")
        }
      }

      jesli cl == nic {
        jesli ma_tresc to rzuc BladParsera.nowy(411, "Length required")
        zwroc ""
      }

      niech dlugosc = cl.liczba()
      jesli dlugosc == nic to rzuc BladParsera.nowy(400, "Invalid Content-Length")
      jesli dlugosc < 0 to rzuc BladParsera.nowy(400, "Invalid Content-Length")
      jesli dlugosc > limity.max_cialo() to rzuc BladParsera.nowy(413, "Payload too large")
      jesli dlugosc == 0 to zwroc ""

      niech tresc = socket.czytaj(dlugosc)
      jesli tresc == nic to rzuc BladParsera.nowy(400, "Body shorter than Content-Length")
      jesli tresc.dlg() < dlugosc to rzuc BladParsera.nowy(400, "Body shorter than Content-Length")
      zwroc tresc
    }

    funkcja parsuj_ciasteczka(header) {
      niech wynik = {}
      niech pary = header.rozdziel(";")

      dla niech k = 0; pary.dlg(); 1 {
        niech para = pary[k].wyczysc()
        jesli para == "" to nastepny

        niech idx = znajdz_znak(para, "=")
        jesli idx == -1 {
          wynik[para] = ""
        } albo {
          niech nazwa = para.wycinek(0, idx - 1).wyczysc()
          niech wartosc = ""
          jesli idx + 1 < para.dlg() to wartosc = para.wycinek(idx + 1, para.dlg() - 1)
          # Strip surrounding quotes if present.
          jesli wartosc.dlg() >= 2 {
            niech pierwszy = wartosc.indeks(0)
            niech ostatni = wartosc.indeks(wartosc.dlg() - 1)
            jesli pierwszy == "\"" i ostatni == "\"" {
              wartosc = wartosc.wycinek(1, wartosc.dlg() - 2)
            }
          }
          wynik[nazwa] = wartosc
        }
      }
      zwroc wynik
    }

    # Helper — finds first occurrence of single char.
    prywatna funkcja znajdz_znak(s, znak) {
      dla niech k = 0; s.dlg(); 1 {
        jesli s.indeks(k) == znak to zwroc k
      }
      zwroc -1
    }
  }
}