modul App {
  modul Walidacja {

    # Each validator returns nic on success or a hash {pole, wiadomosc} on failure.
    # Field-name strings are passed in so messages can target specific UI fields.

    funkcja wymagane(pole, wartosc) {
      jesli wartosc == nic {
        zwroc { "pole": pole, "wiadomosc": "Pole '" + pole + "' jest wymagane" }
      }
      jesli wartosc.typ() == "napis" i wartosc == "" {
        zwroc { "pole": pole, "wiadomosc": "Pole '" + pole + "' nie moze byc puste" }
      }
      zwroc nic
    }

    funkcja minimalna_dlugosc(pole, wartosc, minimum) {
      jesli wartosc == nic to zwroc nic                # let `wymagane` handle this
      jesli wartosc.typ() != "napis" to zwroc nic      # let other validators flag type
      jesli wartosc.dlg() < minimum {
        zwroc {
          "pole": pole,
          "wiadomosc": "Pole '" + pole + "' musi miec co najmniej " + minimum.napis() + " znakow"
        }
      }
      zwroc nic
    }

    funkcja maksymalna_dlugosc(pole, wartosc, maksimum) {
      jesli wartosc == nic to zwroc nic
      jesli wartosc.typ() != "napis" to zwroc nic
      jesli wartosc.dlg() > maksimum {
        zwroc {
          "pole": pole,
          "wiadomosc": "Pole '" + pole + "' nie moze przekraczac " + maksimum.napis() + " znakow"
        }
      }
      zwroc nic
    }

    funkcja format_email(pole, wartosc) {
      jesli wartosc == nic to zwroc nic
      jesli wartosc.typ() != "napis" to zwroc nic
      # Minimal email check: must contain @ and at least one dot after it.
      niech idx_at = znajdz_znak(wartosc, "@")
      jesli idx_at == -1 {
        zwroc { "pole": pole, "wiadomosc": "Email musi zawierac '@'" }
      }
      niech po_at = wartosc.wycinek(idx_at + 1, wartosc.dlg() - 1)
      jesli znajdz_znak(po_at, ".") == -1 {
        zwroc { "pole": pole, "wiadomosc": "Email musi zawierac domene z kropka" }
      }
      zwroc nic
    }

    funkcja typ_tablicy(pole, wartosc) {
      jesli wartosc == nic to zwroc nic
      jesli wartosc.typ() != "tablica" {
        zwroc { "pole": pole, "wiadomosc": "Pole '" + pole + "' musi byc lista" }
      }
      zwroc nic
    }

    funkcja maksymalna_liczba_elementow(pole, wartosc, maksimum) {
      jesli wartosc == nic to zwroc nic
      jesli wartosc.typ() != "tablica" to zwroc nic
      jesli wartosc.dlg() > maksimum {
        zwroc {
          "pole": pole,
          "wiadomosc": "Pole '" + pole + "' nie moze miec wiecej niz " + maksimum.napis() + " elementow"
        }
      }
      zwroc nic
    }

    # Helper: index of first occurrence of single character in string, -1 if absent.
    prywatna funkcja znajdz_znak(s, znak) {
      dla niech k = 0; s.dlg(); 1 {
        jesli s.indeks(k) == znak to zwroc k
      }
      zwroc -1
    }

    # Helper: collects non-nic results into a list of errors.
    funkcja zbierz(lista_walidacji) {
      niech bledy = []
      dla niech k = 0; lista_walidacji.dlg(); 1 {
        niech b = lista_walidacji[k]
        jesli b != nic to bledy << b
      }
      zwroc bledy
    }
  }
}