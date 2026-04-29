import("../lib/zubr")

niech serwer = Zubr::Serwer.nowy(8080)

serwer.middleware(Zubr::Middleware::Log::cichy())

serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Hello, World!\n")
})

serwer.get("/json", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, {
    "message": "Hello",
    "timestamp": Czas.stempel()
  })
})


serwer.get("/users/:id", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, {
    "id": zad.parametry()["id"]
  })
})


serwer.post("/echo", fn(zad) {
  niech dane = zad.dane()
  jesli dane == nic to dane = {}
  zwroc Zubr::Odpowiedz.json(200, dane)
})

serwer.start()

