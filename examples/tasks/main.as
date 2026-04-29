import("../../lib/zubr")
import('./magazyn')

niech magazyn = Magazyn.nowy()
niech app = Zubr::Serwer.nowy(8080)

app.middleware(Zubr::Middleware::Log::standardowy())
app.middleware(Zubr::Middleware::CORS::pozwol("*"))
app.middleware(Zubr::Middleware::Sesja::standardowa("change-me-please-make-this-long"))

app.pliki_statyczne("/static", "./public")

app.get("/", fn(zad) {
  zwroc Zubr::Odpowiedz.plik("./public/index.html")
})

app.get("/tasks", fn(zad) {
  zwroc Zubr::Odpowiedz.json(200, magazyn.wszystkie())
})

app.post("/tasks", fn(zad) {
  niech dane = zad.dane()
  jesli dane == nic to zwroc Zubr::Odpowiedz.json(400, { "error": "missing body" })
  niech tytul = dane["tytul"]
  jesli tytul == nic lub tytul == "" {
    zwroc Zubr::Odpowiedz.json(400, { "error": "tytul required" })
  }
  zwroc Zubr::Odpowiedz.json(201, magazyn.dodaj(tytul))
})

app.get("/tasks/:id", fn(zad) {
  niech z = magazyn.znajdz(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, z)
})

app.put("/tasks/:id/done", fn(zad) {
  niech z = magazyn.oznacz_ukonczone(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, z)
})

app.delete("/tasks/:id", fn(zad) {
  niech z = magazyn.usun(zad.parametry()["id"])
  jesli z == nic to zwroc Zubr::Odpowiedz.json(404, { "error": "not found" })
  zwroc Zubr::Odpowiedz.json(200, { "deleted": z })
})

app.start()