import("./wspolne")

modul App {
  modul Walidacja {
    modul Uzytkownik {

      # Validates registration input. Returns array of errors (empty = OK).
      funkcja rejestracja(dane) {
        jesli dane == nic to zwroc [{ "pole": "_", "wiadomosc": "Brak danych" }]

        niech email = dane["email"]
        niech haslo = dane["haslo"]
        niech nazwa = dane["nazwa"]

        zwroc App::Walidacja::zbierz([
          App::Walidacja::wymagane("email", email),
          App::Walidacja::format_email("email", email),
          App::Walidacja::maksymalna_dlugosc("email", email, 200),

          App::Walidacja::wymagane("haslo", haslo),
          App::Walidacja::minimalna_dlugosc("haslo", haslo, 8),
          App::Walidacja::maksymalna_dlugosc("haslo", haslo, 200),

          App::Walidacja::wymagane("nazwa", nazwa),
          App::Walidacja::minimalna_dlugosc("nazwa", nazwa, 1),
          App::Walidacja::maksymalna_dlugosc("nazwa", nazwa, 100)
        ])
      }

      # Validates login input.
      funkcja login(dane) {
        jesli dane == nic to zwroc [{ "pole": "_", "wiadomosc": "Brak danych" }]

        niech email = dane["email"]
        niech haslo = dane["haslo"]

        zwroc App::Walidacja::zbierz([
          App::Walidacja::wymagane("email", email),
          App::Walidacja::wymagane("haslo", haslo)
        ])
      }
    }
  }
}