import("../lib/zubr")

niech serwer = Zubr::Serwer.nowy(8080)

serwer.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Witaj w Zubrze!\n")
})

serwer.get("/hello", fn(zad) {
  zwroc Zubr::Odpowiedz.html(200, "<h1>Hello, World!</h1>")
})

serwer.get("/users/:id", fn(zad) {
  niech id = zad.parametry()["id"]
  zwroc Zubr::Odpowiedz.json(200, { "user_id": id, "imie": "Anna" })
})

serwer.get("/users/:user_id/posts/:post_id", fn(zad) {
  niech p = zad.parametry()
  zwroc Zubr::Odpowiedz.json(200, {
    "user_id": p["user_id"],
    "post_id": p["post_id"]
  })
})

serwer.post("/echo", fn(zad) {
  zwroc Zubr::Odpowiedz.tekst(200, "Odebrano: " + zad.tresc())
})

serwer.get("/static/*", fn(zad) {
  niech sciezka = zad.parametry()["wildcard"]
  zwroc Zubr::Odpowiedz.tekst(200, "static path: " + sciezka)
})

serwer.trasa_404(fn(zad) {
  zwroc Zubr::Odpowiedz.json(404, {
    "blad": "Nie znaleziono",
    "sciezka": zad.sciezka()
  })
})

serwer.start()