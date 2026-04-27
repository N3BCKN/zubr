import("./response")
import("./codes")
import("plik")
import("digest")

modul Zubr {
  modul PlikiStatyczne {

    # Returns a handler fn(zad) that serves files from `katalog_dyskowy`
    # mounted at `prefix_url`. Use with serwer.trasa("GET", prefix + "/*", handler).
    funkcja handler(prefix_url, katalog_dyskowy) {
      niech katalog_kanoniczny = Plik.rzeczywista_sciezka(katalog_dyskowy)

      zwroc fn(zad) {
        niech sciezka_url = zad.sciezka()

        # Strip prefix to get relative path.
        jesli !zaczyna_sie(sciezka_url, prefix_url) to zwroc Zubr::Odpowiedz.tekst(404, "Not Found")

        niech wzgledna = sciezka_url.wydziel(prefix_url.dlg(), sciezka_url.dlg() - prefix_url.dlg())
        jesli wzgledna == "" to wzgledna = "/"

        niech pelna = Plik.polacz(katalog_dyskowy, wzgledna)

        # Reject path traversal — resolved path must stay within base.
        proba {
          niech kanoniczna = Plik.rzeczywista_sciezka(pelna)
          jesli !zaczyna_sie(kanoniczna, katalog_kanoniczny) to zwroc Zubr::Odpowiedz.tekst(403, "Forbidden")

          pelna = kanoniczna
        } zlap (_) {
          zwroc Zubr::Odpowiedz.tekst(404, "Not Found")
        }

        jesli !Plik.istnieje(pelna) to zwroc Zubr::Odpowiedz.tekst(404, "Not Found")
        jesli Plik.czy_katalog(pelna) to zwroc Zubr::Odpowiedz.tekst(403, "Directory listing not allowed")

        niech mtime = Plik.czas_modyfikacji(pelna)
        niech rozmiar = Plik.rozmiar(pelna)
        niech etag = "\"" + Digest.md5(mtime.timestamp().napis() + "-" + rozmiar.napis()) + "\""

        # Conditional GET — 304 Not Modified.
        niech if_none_match = zad.naglowek("if-none-match")
        jesli if_none_match != nic i if_none_match == etag {
          niech odp = Zubr::Odpowiedz.nowy(304, "")
          odp.naglowek("ETag", etag)
          zwroc odp
        }

        niech if_modified_since = zad.naglowek("if-modified-since")
        jesli if_modified_since != nic {
          proba {
            niech ims = Czas.z_httpdate(if_modified_since)
            jesli !mtime.po(ims) {
              niech odp = Zubr::Odpowiedz.nowy(304, "")
              odp.naglowek("ETag", etag)
              zwroc odp
            }
          } zlap (_) {
          }
        }

        # Serve full content
        niech odp = Zubr::Odpowiedz.plik(pelna)
        odp.naglowek("ETag", etag)
        odp.naglowek("Last-Modified", mtime.httpdate())
        zwroc odp
      }
    }

    # String prefix check — workaround for missing String#zaczyna_sie.
    prywatna funkcja zaczyna_sie(s, prefix) {
      jesli prefix.dlg() > s.dlg() to zwroc falsz
      jesli prefix.dlg() == 0 to zwroc prawda
      niech glowa = s.wydziel(0, prefix.dlg())
      zwroc glowa == prefix
    }
  }
}