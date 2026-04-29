klasa Magazyn {
  funkcja konstruktor() {
    niech @zadania = {}
    niech @nastepne_id = 1
  }

  funkcja dodaj(tytul) {
    niech id = @nastepne_id.napis()
    @nastepne_id = @nastepne_id + 1

    niech zadanie = {
      "id": id,
      "tytul": tytul,
      "ukonczone": falsz,
      "utworzone": Czas.stempel()
    }
    @zadania[id] = zadanie
    zwroc zadanie
  }

  funkcja wszystkie() {
    niech wynik = []
    niech klucze = Json.klucze(@zadania)
    dla niech k = 0; klucze.dlg(); 1 {
      wynik << @zadania[klucze[k]]
    }
    zwroc wynik
  }

  funkcja znajdz(id) {
    zwroc @zadania[id]
  }

  funkcja oznacz_ukonczone(id) {
    niech z = @zadania[id]
    jesli z == nic to zwroc nic
    z["ukonczone"] = prawda
    zwroc z
  }

  funkcja usun(id) {
    niech z = @zadania[id]
    @zadania[id] = nic
    zwroc z
  }
}

niech magazyn = Magazyn.nowy()