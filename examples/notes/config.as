modul App {
  modul Config {

    klasa _Wartosci {
      funkcja konstruktor() {
        niech @port = 8080
        niech @host = "0.0.0.0"
        niech @sciezka_danych = "./data.json"
        niech @sciezka_public = "./public"
        niech @sekret_sesji = "zmien-mnie-w-produkcji-i-niech-ten-string-bedzie-naprawde-dlugi"
        niech @czas_zycia_sesji = 86400
        niech @max_dlugosc_tytulu = 200
        niech @max_dlugosc_tresci = 100000
        niech @max_tagow = 20
        niech @max_dlugosc_tagu = 50
        niech @rate_limit_req = 1000
        niech @rate_limit_okno = 60
      }

      funkcja port() { zwroc @port }
      funkcja host() { zwroc @host }
      funkcja sciezka_danych() { zwroc @sciezka_danych }
      funkcja sciezka_public() { zwroc @sciezka_public }
      funkcja sekret_sesji() { zwroc @sekret_sesji }
      funkcja czas_zycia_sesji() { zwroc @czas_zycia_sesji }
      funkcja max_dlugosc_tytulu() { zwroc @max_dlugosc_tytulu }
      funkcja max_dlugosc_tresci() { zwroc @max_dlugosc_tresci }
      funkcja max_tagow() { zwroc @max_tagow }
      funkcja max_dlugosc_tagu() { zwroc @max_dlugosc_tagu }
      funkcja rate_limit_req() { zwroc @rate_limit_req }
      funkcja rate_limit_okno() { zwroc @rate_limit_okno }
    }

    funkcja _init() {
      globalna niech _CONFIG = _Wartosci.nowy()
    }

    funkcja config() {
      zwroc _CONFIG
    }
  }
}