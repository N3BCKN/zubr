import('czas')

modul Zubr {
  modul Logger {

    klasa Standardowy {
      funkcja konstruktor() {
        niech @prefix = "[zubr]"
      }

      funkcja zapisz(zad, odp) {
        niech czas = Czas.teraz().format("%H:%M:%S")
        niech linia = @prefix + " " + czas + " " + zad.metoda() + " " + zad.sciezka_surowa() + " -> " + odp.status().napis()
        pokazl linia
      }

      funkcja blad(zad, e) {
        niech czas = Czas.teraz().format("%H:%M:%S")
        niech wiadomosc = "unknown"
        proba {
          wiadomosc = e["wiadomosc"]
        } zlap (_) {
        }

        niech kontekst = "(no request)"
        jesli zad != nic {
          kontekst = zad.metoda() + " " + zad.sciezka_surowa()
        }

        pokazl @prefix + " " + czas + " ERR " + kontekst + " :: " + wiadomosc
      }

      funkcja info(tekst) {
        niech czas = Czas.teraz().format("%H:%M:%S")
        pokazl @prefix + " " + czas + " INFO " + tekst
      }
    }

    funkcja domyslny() {
      zwroc Standardowy.nowy()
    }

    klasa Cichy {
      funkcja konstruktor() {
      }
      funkcja zapisz(zad, odp) {
      }
      funkcja blad(zad, e) {
      }
      funkcja info(tekst) {
      }
    }

    funkcja cichy() {
      zwroc Cichy.nowy()
    }
  }
}