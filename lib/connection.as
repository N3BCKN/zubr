import("./codes")
import("./parser")
import("./response")

modul Zubr {
  modul Polaczenie {

    klasa Konfiguracja {
      funkcja konstruktor() {
        niech @limity = Zubr::Parser::Limity.nowy()
        niech @max_requestow_keepalive = 100
        niech @logger = nic
      }

      funkcja limity() { zwroc @limity }
      funkcja max_requestow_keepalive() { zwroc @max_requestow_keepalive }
      funkcja logger() { zwroc @logger }

      funkcja ustaw_logger(l) {
        @logger = l
        zwroc sam
      }

      funkcja ustaw_max_requestow_keepalive(n) {
        @max_requestow_keepalive = n
        zwroc sam
      }
    }

    # Dispatcher signature: fn(zadanie) -> Odpowiedz.
    # Sync. Runs in a per-connection Ruby thread.
    funkcja obsluz(socket, dispatcher, config) {
      niech licznik = 0
      niech max_req = config.max_requestow_keepalive()
      niech logger = config.logger()

      proba {
        dopoki licznik < max_req {
          niech zad = nic
          niech blad_p = nic

          proba {
            zad = Zubr::Parser::czytaj(socket, config.limity())
          } zlap (e) {
            blad_p = e
          }

          jesli blad_p != nic {
            proba {
              wyslij_blad_parsera(socket, blad_p)
            } zlap (_) {
            }
            zakoncz
          }

          jesli zad == nic {
            zakoncz
          }

          licznik = licznik + 1

          niech odp = nic
          proba {
            odp = dispatcher(zad)
          } zlap (e) {
            odp = Zubr::Odpowiedz.tekst(500, "Internal Server Error")
            proba {
              log_wyjatek(logger, zad, e)
            } zlap (_) {
            }
          }

          jesli odp == nic {
            odp = Zubr::Odpowiedz.tekst(500, "Handler returned nic")
          }

          niech trzymaj = zad.czy_keep_alive()
          jesli !trzymaj {
            odp.zamknij()
          }

          niech wyslij_ok = prawda
          proba {
            jesli odp.czy_streaming() {
              wyslij_streaming(socket, odp)
            } albo {
              socket.wyslij(odp.do_bajtow())
            }
          } zlap (_) {
            wyslij_ok = falsz
          }

          jesli !wyslij_ok {
            zakoncz
          }

          proba {
            log_request(logger, zad, odp)
          } zlap (_) {
          }

          jesli !trzymaj {
            zakoncz
          }
        }
      } zlap (e) {
        proba {
          log_wyjatek(logger, nic, e)
        } zlap (_) {
        }
      }
      # Socket closure handled by SerwerTcp::uruchom_petle ensure block.
    }

    funkcja wyslij_streaming(socket, odp) {
      socket.wyslij(odp.zbuduj_naglowki())

      niech source = odp.stream_source()
      dopoki prawda {
        niech chunk = source()
        jesli chunk == nic to zakoncz
        jesli chunk == "" to zakoncz
        socket.wyslij(chunk)
      }
    }

    funkcja wyslij_blad_parsera(socket, e) {
      niech status = 400
      niech msg = "Bad Request"

      proba {
        status = e.status()
        msg = e.wiadomosc()
      } zlap (_) {
      }

      niech odp = Zubr::Odpowiedz.tekst(status, msg)
      odp.zamknij()

      proba {
        socket.wyslij(odp.do_bajtow())
      } zlap (_) {
      }
    }

    funkcja log_request(logger, zad, odp) {
      jesli logger == nic {
        zwroc nic
      }
      logger.zapisz(zad, odp)
    }

    funkcja log_wyjatek(logger, zad, e) {
      jesli logger == nic {
        zwroc nic
      }
      logger.blad(zad, e)
    }
  }
}