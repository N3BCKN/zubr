import("securerandom")
import("czas")

modul App {
  modul Modele {

    klasa Notatka {
      funkcja konstruktor(id, autor_id, tytul, tresc, tagi, utworzona, zmodyfikowana) {
        niech @id = id
        niech @autor_id = autor_id
        niech @tytul = tytul
        niech @tresc = tresc
        niech @tagi = tagi
        niech @utworzona = utworzona
        niech @zmodyfikowana = zmodyfikowana
      }

      funkcja identyfikator() { zwroc @id }
      funkcja autor_id() { zwroc @autor_id }
      funkcja tytul() { zwroc @tytul }
      funkcja tresc() { zwroc @tresc }
      funkcja tagi() { zwroc @tagi }
      funkcja utworzona() { zwroc @utworzona }
      funkcja zmodyfikowana() { zwroc @zmodyfikowana }

      # Apply edits and bump zmodyfikowana timestamp.
      funkcja aktualizuj(nowy_tytul, nowa_tresc, nowe_tagi) {
        @tytul = nowy_tytul
        @tresc = nowa_tresc
        @tagi = nowe_tagi
        @zmodyfikowana = Czas.stempel()
        zwroc sam
      }

      funkcja czy_nalezy_do(uzytkownik_id) {
        zwroc @autor_id == uzytkownik_id
      }

      funkcja czy_ma_tag(tag) {
        dla niech k = 0; @tagi.dlg(); 1 {
          jesli @tagi[k] == tag to zwroc prawda
        }
        zwroc falsz
      }

      # Case-insensitive substring match in title or content.
      funkcja czy_pasuje_do_zapytania(q) {
        jesli q == "" to zwroc prawda
        niech q_lower = q.malymi()
        jesli @tytul.malymi().zawiera(q_lower) to zwroc prawda
        jesli @tresc.malymi().zawiera(q_lower) to zwroc prawda
        zwroc falsz
      }

      funkcja do_hasha() {
        zwroc {
          "id": @id,
          "autor_id": @autor_id,
          "tytul": @tytul,
          "tresc": @tresc,
          "tagi": @tagi,
          "utworzona": @utworzona,
          "zmodyfikowana": @zmodyfikowana
        }
      }

      statyczna funkcja utworz(autor_id, tytul, tresc, tagi) {
        niech id = "n_" + SecureRandom.hex(12)
        niech teraz = Czas.stempel()
        zwroc Notatka.nowy(id, autor_id, tytul, tresc, tagi, teraz, teraz)
      }

      statyczna funkcja z_hasha(h) {
        zwroc Notatka.nowy(
          h["id"],
          h["autor_id"],
          h["tytul"],
          h["tresc"],
          h["tagi"],
          h["utworzona"],
          h["zmodyfikowana"]
        )
      }
    }
  }
}