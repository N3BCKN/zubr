modul Zubr {
  klasa Odpowiedz {
    funkcja konstruktor(status, tresc) {
      niech @status = status
      jesli tresc == nic {
        niech @tresc = ""
      } albo {
        niech @tresc = tresc
      }
      niech @naglowki = {}
      niech @zamknij_polaczenie = falsz
    }

    funkcja status() { zwroc @status }
    funkcja tresc() { zwroc @tresc }
    funkcja naglowki() { zwroc @naglowki }

    funkcja naglowek(nazwa, wartosc) {
      @naglowki[nazwa] = wartosc
      zwroc sam
    }

    funkcja ustaw_typ(t) {
      @naglowki["Content-Type"] = t
      zwroc sam
    }

    funkcja zamknij() {
      @zamknij_polaczenie = prawda
      zwroc sam
    }

    funkcja czy_zamyka() { zwroc @zamknij_polaczenie }

    funkcja do_bajtow() {
      niech bufor = Zubr::Codes::status_linia(@status)

      jesli @naglowki["Content-Length"] == nic {
        @naglowki["Content-Length"] = @tresc.dlg().napis()
      }
      jesli @naglowki["Date"] == nic {
        @naglowki["Date"] = Czas.teraz().httpdate()
      }
      jesli @naglowki["Server"] == nic {
        @naglowki["Server"] = "Zubr/1.0"
      }
      jesli @naglowki["Connection"] == nic {
        jesli @zamknij_polaczenie {
          @naglowki["Connection"] = "close"
        } albo {
          @naglowki["Connection"] = "keep-alive"
        }
      }

      niech klucze = Json.klucze(@naglowki)
      dla niech idx = 0; klucze.dlg(); 1 {
        niech k = klucze[idx]
        bufor = bufor + k + ": " + @naglowki[k] + "\r\n"
      }

      bufor = bufor + "\r\n" + @tresc
      zwroc bufor
    }

    statyczna funkcja tekst(status, t) {
      niech o = Odpowiedz.nowy(status, t)
      o.ustaw_typ("text/plain; charset=utf-8")
      zwroc o
    }

    statyczna funkcja json(status, dane) {
      niech t = Json.generuj(dane)
      niech o = Odpowiedz.nowy(status, t)
      o.ustaw_typ("application/json; charset=utf-8")
      zwroc o
    }

    statyczna funkcja html(status, t) {
      niech o = Odpowiedz.nowy(status, t)
      o.ustaw_typ("text/html; charset=utf-8")
      zwroc o
    }

    statyczna funkcja przekieruj(url) {
      niech o = Odpowiedz.nowy(302, "")
      o.naglowek("Location", url)
      zwroc o
    }

    statyczna funkcja brak_zawartosci() {
      zwroc Odpowiedz.nowy(204, "")
    }
  }
}