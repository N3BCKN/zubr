import('mat')

modul Zubr {
  modul Middleware {
    modul Log {

      funkcja standardowy() {
        zwroc fn(zad, dalej) {
          niech start = Czas.stempel_f()
          niech odp = dalej(zad)
          niech ms = (Czas.stempel_f() - start) * 1000
          niech ms_zaokr = Mat.zaokraglij(ms, 2)

          niech linia = Czas.teraz().format("[%H:%M:%S]") + " " + zad.metoda() + " " + zad.sciezka_surowa() + " -> " + odp.status().napis() + " " + ms_zaokr.napis() + "ms"
          pokazl linia
          zwroc odp
        }
      }

      funkcja cichy() {
        zwroc fn(zad, dalej) {
          zwroc dalej(zad)
        }
      }
    }
  }
}