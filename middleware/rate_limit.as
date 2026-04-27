modul Zubr {
  modul Middleware {
    modul RateLimit {

      klasa LicznikIP {
        funkcja konstruktor(limit, okno_sekund) {
          niech @limit = limit
          niech @okno_sekund = okno_sekund
          niech @liczniki = {}
          niech @resety = {}
        }

        # Returns prawda if request allowed, falsz if rate limited.
        funkcja zezwol(ip) {
          niech teraz = Czas.stempel()
          niech reset = @resety[ip]

          jesli reset == nic lub teraz >= reset {
            @liczniki[ip] = 1
            @resety[ip] = teraz + @okno_sekund
            zwroc prawda
          }

          niech aktualny = @liczniki[ip]
          jesli aktualny >= @limit to zwroc falsz

          @liczniki[ip] = aktualny + 1
          zwroc prawda
        }

        funkcja pozostalo(ip) {
          niech aktualny = @liczniki[ip]
          jesli aktualny == nic to zwroc @limit
          niech p = @limit - aktualny
          jesli p < 0 to zwroc 0
          zwroc p
        }
      }

      # `limit` — max requests per `okno_sekund` per IP.
      funkcja na_ip(limit, okno_sekund) {
        niech licznik = LicznikIP.nowy(limit, okno_sekund)

        zwroc fn(zad, dalej) {
          niech ip = zad.naglowek("x-forwarded-for")
          jesli ip == nic to ip = "unknown"

          jesli !licznik.zezwol(ip) {
            niech odp = Zubr::Odpowiedz.tekst(429, "Too Many Requests\n")
            odp.naglowek("Retry-After", okno_sekund.napis())
            zwroc odp
          }

          niech odp = dalej(zad)
          odp.naglowek("X-RateLimit-Limit", limit.napis())
          odp.naglowek("X-RateLimit-Remaining", licznik.pozostalo(ip).napis())
          zwroc odp
        }
      }
    }
  }
}