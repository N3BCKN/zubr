import("../lib/zubr")
import("socket")

funkcja dispatcher(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Hello from Zubr!\n")
}

funkcja glowna() {
  niech port = 8080
  niech srv = SerwerTcp.nowy(port, "127.0.0.1")
  niech config = Zubr::Polaczenie::Konfiguracja.nowy()
  config.ustaw_logger(Zubr::Logger::domyslny())

  config.logger().info("Zubr listening on 127.0.0.1:" + port.napis())

  srv.uruchom_petle(fn(klient) {
    Zubr::Polaczenie::obsluz(klient, dispatcher, config)
  })
}

glowna()