import("./test_helper")
import("../lib/zubr")

klasa MockSocket {
  funkcja konstruktor(dane) {
    niech @bufor = dane
    niech @pozycja = 0
  }

  funkcja czytaj_linie() {
    jesli @pozycja >= @bufor.dlg() to zwroc nic

    # Find next \r\n starting from @pozycja using wycinek + indeks loop.
    niech reszta = @bufor.wycinek(@pozycja, @bufor.dlg() - 1)
    niech idx_lokalne = -1
    dla niech k = 0; reszta.dlg() - 1; 1 {
      jesli reszta.indeks(k) == "\r" {
        jesli reszta.indeks(k + 1) == "\n" {
          idx_lokalne = k
          zakoncz
        }
      }
    }

    jesli idx_lokalne == -1 {
      @pozycja = @bufor.dlg()
      zwroc reszta
    }

    niech linia = reszta.wycinek(0, idx_lokalne - 1)
    jesli idx_lokalne == 0 to linia = ""
    @pozycja = @pozycja + idx_lokalne + 2
    zwroc linia
  }

  funkcja czytaj(n) {
    jesli @pozycja >= @bufor.dlg() to zwroc nic
    niech koniec_pos = @pozycja + n - 1
    jesli koniec_pos >= @bufor.dlg() to koniec_pos = @bufor.dlg() - 1
    niech wynik = @bufor.wycinek(@pozycja, koniec_pos)
    @pozycja = koniec_pos + 1
    zwroc wynik
  }
}

funkcja zbuduj_request(metoda, sciezka, naglowki, tresc) {
  niech bufor = metoda + " " + sciezka + " HTTP/1.1\r\n"
  niech klucze = Json.klucze(naglowki)
  dla niech k = 0; klucze.dlg(); 1 {
    bufor = bufor + klucze[k] + ": " + naglowki[klucze[k]] + "\r\n"
  }
  bufor = bufor + "\r\n" + tresc
  zwroc bufor
}

niech limity = Zubr::Parser::Limity.nowy()

Test::_init_stan()

Test::grupa("Parser: request line", fn() {
  niech sock = MockSocket.nowy("GET / HTTP/1.1\r\n\r\n")
  niech zad = Zubr::Parser::czytaj(sock, limity)
  Test::sprawdz_rowne(zad.metoda(), "GET", "method")
  Test::sprawdz_rowne(zad.sciezka(), "/", "path")
  Test::sprawdz_rowne(zad.wersja(), "HTTP/1.1", "version")
})

Test::grupa("Parser: query string", fn() {
  niech sock = MockSocket.nowy("GET /search?q=hello&limit=10 HTTP/1.1\r\n\r\n")
  niech zad = Zubr::Parser::czytaj(sock, limity)
  Test::sprawdz_rowne(zad.sciezka(), "/search", "path without query")
  Test::sprawdz_rowne(zad.zapytanie()["q"], "hello", "query param q")
  Test::sprawdz_rowne(zad.zapytanie()["limit"], "10", "query param limit")
})

Test::grupa("Parser: URL decoding", fn() {
  niech sock = MockSocket.nowy("GET /hello%20world HTTP/1.1\r\n\r\n")
  niech zad = Zubr::Parser::czytaj(sock, limity)
  Test::sprawdz_rowne(zad.sciezka(), "/hello world", "URL-decoded path")
})

Test::grupa("Parser: headers", fn() {
  niech sock = MockSocket.nowy("GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: test/1.0\r\n\r\n")
  niech zad = Zubr::Parser::czytaj(sock, limity)
  Test::sprawdz_rowne(zad.naglowek("host"), "example.com", "Host header")
  Test::sprawdz_rowne(zad.naglowek("Host"), "example.com", "case-insensitive lookup")
  Test::sprawdz_rowne(zad.naglowek("user-agent"), "test/1.0", "User-Agent")
})

Test::grupa("Parser: body with Content-Length", fn() {
  niech tresc = "{\"a\":1}"
  niech req = "POST /api HTTP/1.1\r\nContent-Length: 7\r\nContent-Type: application/json\r\n\r\n" + tresc
  niech sock = MockSocket.nowy(req)
  niech zad = Zubr::Parser::czytaj(sock, limity)
  Test::sprawdz_rowne(zad.tresc(), tresc, "body matches")
  niech parsed = zad.json()
  Test::sprawdz_rowne(parsed["a"], 1, "JSON parsed")
})

Test::grupa("Parser: errors", fn() {
  Test::sprawdz_rzuca(fn() {
    Zubr::Parser::czytaj(MockSocket.nowy("INVALID\r\n\r\n"), limity)
  }, "malformed request line raises")

  Test::sprawdz_rzuca(fn() {
    Zubr::Parser::czytaj(MockSocket.nowy("FOO / HTTP/1.1\r\n\r\n"), limity)
  }, "unknown method raises")

  Test::sprawdz_rzuca(fn() {
    Zubr::Parser::czytaj(MockSocket.nowy("POST /api HTTP/1.1\r\n\r\n"), limity)
  }, "POST without Content-Length raises 411")
})

Test::grupa("Parser: keep-alive detection", fn() {
  niech s1 = MockSocket.nowy("GET / HTTP/1.1\r\n\r\n")
  Test::sprawdz(Zubr::Parser::czytaj(s1, limity).czy_keep_alive(), "HTTP/1.1 default keep-alive")

  niech s2 = MockSocket.nowy("GET / HTTP/1.1\r\nConnection: close\r\n\r\n")
  Test::sprawdz(!Zubr::Parser::czytaj(s2, limity).czy_keep_alive(), "Connection: close")
})

Test::grupa("Parser: clean EOF", fn() {
  niech sock = MockSocket.nowy("")
  niech zad = Zubr::Parser::czytaj(sock, limity)
  Test::sprawdz(zad == nic, "empty input returns nic")
})

Test::podsumuj()