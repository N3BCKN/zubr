modul Zubr {
  modul Middleware {

    # Wrap one middleware around an inner handler.
    # Factored out so each iteration captures its own mw/inner.
    prywatna funkcja oplec(mw, wewnetrzny) {
      zwroc fn(zad) {
        zwroc mw(zad, wewnetrzny)
      }
    }

    funkcja zbuduj(lista_mw, finalny_handler) {
      niech aktualny = finalny_handler

      dla niech k = lista_mw.dlg() - 1; -1; -1 {
        aktualny = oplec(lista_mw[k], aktualny)
      }

      zwroc aktualny
    }
  }
}