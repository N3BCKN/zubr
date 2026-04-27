import("./codes")
import("./parser")
import("./response")
import("./logger")
import("./connection")
import("./router")
import("socket")

modul Zubr {

  klasa Serwer {
    funkcja konstruktor(port) {
      niech @port = port
      niech @host = "0.0.0.0"
      niech @router = Zubr::Router::SilnikRoutingu.nowy()
      niech @config = Zubr::Polaczenie::Konfiguracja.nowy()
      niech @middleware_lista = []
      niech @stop_request = falsz
      @config.ustaw_logger(Zubr::Logger::domyslny())
    }


    funkcja port() { zwroc @port }
    funkcja host() { zwroc @host }
    funkcja router() { zwroc @router }
    funkcja config() { zwroc @config }


    funkcja middleware(mw) {
      @middleware_lista << mw
      zwroc sam
    }

    funkcja zatrzymaj() {
      @stop_request = prawda
      zwroc sam
    }

    funkcja pliki_statyczne(prefix_url, katalog_dyskowy) {
      niech h = Zubr::PlikiStatyczne::handler(prefix_url, katalog_dyskowy)
      sam.trasa("GET", prefix_url + "/*", h)
      zwroc sam
    }

    funkcja ustaw_host(h) {
      @host = h
      zwroc sam
    }

    funkcja ustaw_logger(l) {
      @config.ustaw_logger(l)
      zwroc sam
    }

    funkcja trasa(metoda, wzor, handler) {
      @router.dodaj(metoda, wzor, handler)
      zwroc sam
    }

    funkcja trasa_regex(metoda, regex, handler) {
      @router.dodaj_regex(metoda, regex, handler)
      zwroc sam
    }

    funkcja trasa_404(handler) {
      @router.ustaw_404(handler)
      zwroc sam
    }

    # Convenience verbs.
    funkcja get(wzor, handler) { zwroc sam.trasa("GET", wzor, handler) }
    funkcja post(wzor, handler) { zwroc sam.trasa("POST", wzor, handler) }
    funkcja put(wzor, handler) { zwroc sam.trasa("PUT", wzor, handler) }
    funkcja patch(wzor, handler) { zwroc sam.trasa("PATCH", wzor, handler) }
    funkcja delete(wzor, handler) { zwroc sam.trasa("DELETE", wzor, handler) }

    funkcja start() {
      Zubr::_init_data_cache()
      niech srv = SerwerTcp.nowy(@port, @host)
      @config.logger().info("Zubr listening on " + @host + ":" + @port.napis())

      niech router_ref = @router
      niech config_ref = @config

      niech finalny = fn(zad) {
        zwroc router_ref.dispatch(zad)
      }

      niech dispatcher = Zubr::Middleware::zbuduj(@middleware_lista, finalny)

      srv.uruchom_petle(fn(klient) {
        Zubr::Polaczenie::obsluz(klient, dispatcher, config_ref)
      })
    }
  }
}