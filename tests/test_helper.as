modul Test {
  klasa _Stan {
    funkcja konstruktor() {
      niech @zaliczone = 0
      niech @niezaliczone = 0
      niech @bledy = []
    }

    funkcja zaliczone() { zwroc @zaliczone }
    funkcja niezaliczone() { zwroc @niezaliczone }
    funkcja bledy() { zwroc @bledy }

    funkcja inkrementuj_ok() { @zaliczone = @zaliczone + 1 }
    funkcja inkrementuj_zle(opis) {
      @niezaliczone = @niezaliczone + 1
      @bledy << opis
    }
  }

  funkcja _init_stan() {
    globalna niech _STAN_REF = _Stan.nowy()
  }

  funkcja _stan() {
    zwroc _STAN_REF
  }

  funkcja sprawdz(warunek, opis) {
    jesli warunek {
      _stan().inkrementuj_ok()
    } albo {
      _stan().inkrementuj_zle(opis)
      pokazl "  FAIL: " + opis
    }
  }

  funkcja sprawdz_rowne(rzecz, ocz, opis) {
    jesli rzecz == ocz {
      _stan().inkrementuj_ok()
    } albo {
      niech msg = opis + " (expected: " + ocz.napis() + ", got: " + rzecz.napis() + ")"
      _stan().inkrementuj_zle(msg)
      pokazl "  FAIL: " + msg
    }
  }

  funkcja sprawdz_rzuca(blok, opis) {
    niech rzucilo = falsz
    proba {
      blok()
    } zlap (e) {
      rzucilo = prawda
    }
    sprawdz(rzucilo, opis)
  }

  funkcja podsumuj() {
    pokazl ""
    pokazl "===================="
    pokazl "Zaliczone: " + _stan().zaliczone().napis()
    pokazl "Niezaliczone: " + _stan().niezaliczone().napis()
    pokazl "===================="
    zwroc _stan().niezaliczone() == 0
  }

  funkcja grupa(nazwa, blok) {
    pokazl ""
    pokazl "--- " + nazwa + " ---"
    blok()
  }
}