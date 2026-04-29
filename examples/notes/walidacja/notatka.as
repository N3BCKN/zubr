import("./wspolne")
import("../config")

modul App {
  modul Walidacja {
    modul Notatka {

      funkcja utworz(dane) {
        zwroc waliduj_notatke(dane)
      }

      funkcja aktualizuj(dane) {
        zwroc waliduj_notatke(dane)
      }

      prywatna funkcja waliduj_notatke(dane) {
        jesli dane == nic to zwroc [{ "pole": "_", "wiadomosc": "Brak danych" }]

        niech cfg = App::Config::config()
        niech tytul = dane["tytul"]
        niech tresc = dane["tresc"]
        niech tagi = dane["tagi"]

        niech podstawowe = App::Walidacja::zbierz([
          App::Walidacja::wymagane("tytul", tytul),
          App::Walidacja::maksymalna_dlugosc("tytul", tytul, cfg.max_dlugosc_tytulu()),

          # tresc may be empty — only enforce upper bound
          App::Walidacja::maksymalna_dlugosc("tresc", tresc, cfg.max_dlugosc_tresci()),

          # tagi must be an array if provided; nic is treated as empty
          App::Walidacja::typ_tablicy("tagi", tagi),
          App::Walidacja::maksymalna_liczba_elementow("tagi", tagi, cfg.max_tagow())
        ])

        # Per-tag validation
        jesli tagi != nic i tagi.typ() == "tablica" {
          dla niech k = 0; tagi.dlg(); 1 {
            niech tag = tagi[k]
            jesli tag.typ() != "napis" {
              podstawowe << { "pole": "tagi", "wiadomosc": "Wszystkie tagi musza byc tekstem" }
              przerwij
            }
            jesli tag.dlg() == 0 {
              podstawowe << { "pole": "tagi", "wiadomosc": "Tag nie moze byc pusty" }
              przerwij
            }
            jesli tag.dlg() > cfg.max_dlugosc_tagu() {
              podstawowe << {
                "pole": "tagi",
                "wiadomosc": "Tag '" + tag + "' przekracza " + cfg.max_dlugosc_tagu().napis() + " znakow"
              }
              przerwij
            }
          }
        }

        zwroc podstawowe
      }
    }
  }
}