modul Zubr {
  modul Middleware {
    modul CORS {

      # `originy` — array of allowed origin strings, or single string "*".
      funkcja pozwol(originy) {
        niech dozwolone = originy

        zwroc fn(zad, dalej) {
          niech origin = zad.naglowek("origin")
          niech dopasowany = dopasuj_origin(dozwolone, origin)

          # OPTIONS preflight — short-circuit before reaching the handler.
          jesli zad.metoda() == "OPTIONS" {
            niech odp = Zubr::Odpowiedz.brak_zawartosci()
            jesli dopasowany != nic {
              odp.naglowek("Access-Control-Allow-Origin", dopasowany)
              odp.naglowek("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
              odp.naglowek("Access-Control-Allow-Headers", "Content-Type, Authorization")
              odp.naglowek("Access-Control-Max-Age", "86400")
            }
            zwroc odp
          }

          niech odp = dalej(zad)
          jesli dopasowany != nic {
            odp.naglowek("Access-Control-Allow-Origin", dopasowany)
          }
          zwroc odp
        }
      }

      prywatna funkcja dopasuj_origin(dozwolone, request_origin) {
        jesli dozwolone == "*" to zwroc "*"
        jesli request_origin == nic to zwroc nic

        # Array of allowed origins.
        dla niech k = 0; dozwolone.dlg(); 1 {
          jesli dozwolone[k] == request_origin to zwroc request_origin
        }
        zwroc nic
      }
    }
  }
}