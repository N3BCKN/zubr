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
      niech @stream_source = nic
      niech @stream_size = 0
    }

    funkcja status() { zwroc @status }
    funkcja tresc() { zwroc @tresc }
    funkcja naglowki() { zwroc @naglowki }

    funkcja czy_streaming() { zwroc @stream_source != nic }
    funkcja stream_source() { zwroc @stream_source }
    funkcja stream_size() { zwroc @stream_size }

    funkcja naglowek(nazwa, wartosc) {
      @naglowki[nazwa] = wartosc
      zwroc sam
    }

    funkcja ustaw_typ(t) {
      @naglowki["Content-Type"] = t
      zwroc sam
    }

    funkcja ustaw_tresc(s) {
      @tresc = s
      zwroc sam
    }

    funkcja zamknij() {
      @zamknij_polaczenie = prawda
      zwroc sam
    }

    funkcja czy_zamyka() { zwroc @zamknij_polaczenie }

    funkcja do_bajtow() {
      jesli @stream_source != nic {
        rzuc BladWykonania.nowy("do_bajtow nie obsluguje streamingu - uzyj zbuduj_naglowki + zapisz_chunk")
      }
      zwroc sam.zbuduj_naglowki() + @tresc
    }

    # Configure streaming. `source` is a function fn() -> next_chunk_string or nic on EOF.
    # `total_size` lets us set Content-Length up front (for files where we know size).
    funkcja ustaw_stream(source, total_size) {
      @stream_source = source
      @stream_size = total_size
      zwroc sam
    }

    # Builds only the headers part. Used by streaming responses where body
    # is sent separately, chunk by chunk, directly to the socket.
    funkcja zbuduj_naglowki() {
      niech bufor = Zubr::Codes::status_linia(@status)

      jesli @stream_source != nic {
        @naglowki["Content-Length"] = @stream_size.napis()
      } albojesli @naglowki["Content-Length"] == nic {
        @naglowki["Content-Length"] = @tresc.dlg().napis()
      }

      jesli @naglowki["Date"] == nic {
        @naglowki["Date"] = Zubr::_data_cache().teraz()
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

      bufor = bufor + "\r\n"
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

    statyczna funkcja plik(sciezka) {
      jesli !Plik.istnieje(sciezka) to zwroc Odpowiedz.tekst(404, "Not Found")
      jesli Plik.czy_katalog(sciezka) to zwroc Odpowiedz.tekst(403, "Forbidden")

      niech rozmiar = Plik.rozmiar(sciezka)
      niech mime = Zubr::Codes::mime_z_rozszerzenia(Plik.rozszerzenie(sciezka))

      # Small files — load fully into memory.
      jesli rozmiar < 65536 {
        niech tresc = Plik.czytaj(sciezka)
        niech o = Odpowiedz.nowy(200, tresc)
        o.ustaw_typ(mime)
        zwroc o
      }

      # Large files — stream in 64KB chunks.
      niech f = Plik.nowy(sciezka, "r")
      niech o = Odpowiedz.nowy(200, "")
      o.ustaw_typ(mime)
      o.ustaw_stream(Odpowiedz.stream_z_pliku(f), rozmiar)
      zwroc o
    }

    # Returns a closure that yields next 64KB chunk on each call,
    # returns nic when EOF and closes the file.
    statyczna funkcja stream_z_pliku(f) {
      niech zamkniety = falsz
      zwroc fn() {
        jesli zamkniety to zwroc nic
        niech chunk = f.czytaj(65536)
        jesli chunk == nic lub chunk == "" {
          f.zamknij()
          zamkniety = prawda
          zwroc nic
        }
        zwroc chunk
      }
    }
  }

  klasa _DataCache {
    funkcja konstruktor() {
      niech @ostatni_sek = 0
      niech @ostatni_str = ""
    }

    funkcja teraz() {
      niech sek = Czas.stempel()
      jesli sek == @ostatni_sek to zwroc @ostatni_str
      @ostatni_sek = sek
      @ostatni_str = Czas.teraz().httpdate()
      zwroc @ostatni_str
    }
  }

  funkcja _init_data_cache() {
    globalna niech _DC = _DataCache.nowy()
  }

  funkcja _data_cache() {
    zwroc _DC
  }
}