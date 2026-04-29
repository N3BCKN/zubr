import("securerandom")
import("digest")
import("czas")

modul App {
  modul Modele {

    klasa Uzytkownik {
      funkcja konstruktor(id, email, nazwa, haslo_hash, haslo_sol, utworzony) {
        niech @id = id
        niech @email = email
        niech @nazwa = nazwa
        niech @haslo_hash = haslo_hash
        niech @haslo_sol = haslo_sol
        niech @utworzony = utworzony
      }

      funkcja identyfikator() { zwroc @id }
      funkcja email() { zwroc @email }
      funkcja nazwa() { zwroc @nazwa }
      funkcja haslo_hash() { zwroc @haslo_hash }
      funkcja haslo_sol() { zwroc @haslo_sol }
      funkcja utworzony() { zwroc @utworzony }

      # Constant-time password verification.
      funkcja sprawdz_haslo(haslo_plaintext) {
        niech sprawdzany = Digest.sha256(@haslo_sol + haslo_plaintext)
        zwroc Digest.porownaj(sprawdzany, @haslo_hash)
      }

      # Serialization for persistence and API responses.
      funkcja do_hasha_pelnego() {
        zwroc {
          "id": @id,
          "email": @email,
          "nazwa": @nazwa,
          "haslo_hash": @haslo_hash,
          "haslo_sol": @haslo_sol,
          "utworzony": @utworzony
        }
      }

      # Public-facing — no password fields, safe to send to client.
      funkcja do_hasha_publicznego() {
        zwroc {
          "id": @id,
          "email": @email,
          "nazwa": @nazwa,
          "utworzony": @utworzony
        }
      }

      # Factory: create a new user from registration input.
      # Generates id, salt, hashes the password.
      statyczna funkcja utworz(email, nazwa, haslo_plaintext) {
        niech id = "u_" + SecureRandom.hex(12)
        niech sol = SecureRandom.hex(16)
        niech hash = Digest.sha256(sol + haslo_plaintext)
        niech teraz = Czas.stempel()
        zwroc Uzytkownik.nowy(id, email, nazwa, hash, sol, teraz)
      }

      # Factory: rehydrate from persisted hash.
      statyczna funkcja z_hasha(h) {
        zwroc Uzytkownik.nowy(
          h["id"],
          h["email"],
          h["nazwa"],
          h["haslo_hash"],
          h["haslo_sol"],
          h["utworzony"]
        )
      }
    }
  }
}