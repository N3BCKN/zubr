import("securerandom")
import("digest")

modul Zubr {
  modul Middleware {
    modul Sesja {

      # Per-process store — shared across all connection threads.
      # Hash: id => { dane: {}, utworzona: int, ostatnio: int }

      funkcja _init_store() {
        globalna niech _SESJA_STORE = {}
      }

      funkcja _get_store() {
        zwroc _SESJA_STORE
      }

      # Session proxy passed to handlers via zad.sesja().
      # Tracks dirty flag and destroyed flag so middleware knows whether to persist.
      klasa Sesja {
        funkcja konstruktor(id, dane) {
          niech @id = id
          niech @dane = dane
          niech @brudna = falsz
          niech @zniszczona = falsz
        }

        funkcja identyfikator() { zwroc @id }
        funkcja dane() { zwroc @dane }
        funkcja czy_brudna() { zwroc @brudna }
        funkcja czy_zniszczona() { zwroc @zniszczona }

        funkcja pobierz(klucz) {
          zwroc @dane[klucz]
        }

        funkcja ustaw(klucz, wartosc) {
          @dane[klucz] = wartosc
          @brudna = prawda
          zwroc sam
        }

        funkcja usun(klucz) {
          @dane[klucz] = nic
          @brudna = prawda
          zwroc sam
        }

        funkcja zniszcz() {
          @zniszczona = prawda
          @brudna = prawda
          zwroc sam
        }
      }

      # Build the middleware. `sekret` is the HMAC key — keep it stable across restarts
      # if you want sessions to survive server restarts (but data is in-memory anyway,
      # so they won't unless you add persistence).
      funkcja standardowa(sekret) {
        Zubr::Middleware::Sesja::_init_store()
        zwroc fabryka_middleware(sekret, "_zubr_sesja", 86400)
      }

      # Configurable variant.
      funkcja konfigurowalna(sekret, nazwa_cookie, czas_zycia_sek) {
        Zubr::Middleware::Sesja::_init_store()
        zwroc fabryka_middleware(sekret, nazwa_cookie, czas_zycia_sek)
      }

      prywatna funkcja fabryka_middleware(sekret, nazwa_cookie, czas_zycia_sek) {
        zwroc fn(zad, dalej) {
          niech raw = zad.ciasteczko(nazwa_cookie)
          niech sesja = zaladuj_lub_utworz(raw, sekret)
          zad.ustaw_sesja(sesja)
          niech odp = dalej(zad)
          zapisz_jesli_potrzeba(odp, sesja, sekret, nazwa_cookie, czas_zycia_sek)
          zwroc odp
        }
      }

      prywatna funkcja zaladuj_lub_utworz(raw, sekret) {
        # Cookie not present → fresh session.
        jesli raw == nic to zwroc nowa_sesja()
        jesli raw == "" to zwroc nowa_sesja()

        # Format: id.signature
        niech kropka = znajdz_kropke(raw)
        jesli kropka == -1 to zwroc nowa_sesja()

        niech id = raw.wycinek(0, kropka - 1)
        niech sig = raw.wycinek(kropka + 1, raw.dlg() - 1)
        niech oczekiwana_sig = Digest.hmac_sha256(sekret, id)

        # Constant-time compare against forgery.
        jesli !Digest.porownaj(sig, oczekiwana_sig) to zwroc nowa_sesja()

        niech store = _get_store()
        niech wpis = store[id]
        jesli wpis == nic to zwroc nowa_sesja()

        # Refresh last-seen timestamp.
        wpis["ostatnio"] = Czas.stempel()
        zwroc Sesja.nowy(id, wpis["dane"])
      }

      prywatna funkcja nowa_sesja() {
        niech id = SecureRandom.hex(24)
        zwroc Sesja.nowy(id, {})
      }

      prywatna funkcja zapisz_jesli_potrzeba(odp, sesja, sekret, nazwa_cookie, czas_zycia_sek) {
        niech store = _get_store()

        jesli sesja.czy_zniszczona() {
          store[sesja.identyfikator()] = nic
          odp.usun_ciasteczko(nazwa_cookie)
          zwroc nic
        }

        jesli !sesja.czy_brudna() to zwroc nic

        store[sesja.identyfikator()] = {
          "dane": sesja.dane(),
          "utworzona": Czas.stempel(),
          "ostatnio": Czas.stempel()
        }

        niech sig = Digest.hmac_sha256(sekret, sesja.identyfikator())
        niech wartosc = sesja.identyfikator() + "." + sig

        odp.ustaw_ciasteczko(nazwa_cookie, wartosc, {
          "max_age": czas_zycia_sek,
          "path": "/",
          "http_only": prawda,
          "same_site": "Lax"
        })
      }

      prywatna funkcja znajdz_kropke(s) {
        dla niech k = 0; s.dlg(); 1 {
          jesli s.indeks(k) == "." to zwroc k
        }
        zwroc -1
      }
    }
  }
}