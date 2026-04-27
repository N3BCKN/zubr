modul Zubr {
  modul Codes {
    klasa _Tablice {
      funkcja konstruktor() {
        niech @statusy = {
          "100": "HTTP/1.1 100 Continue\r\n",
          "200": "HTTP/1.1 200 OK\r\n",
          "201": "HTTP/1.1 201 Created\r\n",
          "204": "HTTP/1.1 204 No Content\r\n",
          "301": "HTTP/1.1 301 Moved Permanently\r\n",
          "302": "HTTP/1.1 302 Found\r\n",
          "304": "HTTP/1.1 304 Not Modified\r\n",
          "400": "HTTP/1.1 400 Bad Request\r\n",
          "401": "HTTP/1.1 401 Unauthorized\r\n",
          "403": "HTTP/1.1 403 Forbidden\r\n",
          "404": "HTTP/1.1 404 Not Found\r\n",
          "405": "HTTP/1.1 405 Method Not Allowed\r\n",
          "408": "HTTP/1.1 408 Request Timeout\r\n",
          "411": "HTTP/1.1 411 Length Required\r\n",
          "413": "HTTP/1.1 413 Payload Too Large\r\n",
          "414": "HTTP/1.1 414 URI Too Long\r\n",
          "431": "HTTP/1.1 431 Request Header Fields Too Large\r\n",
          "500": "HTTP/1.1 500 Internal Server Error\r\n",
          "501": "HTTP/1.1 501 Not Implemented\r\n",
          "503": "HTTP/1.1 503 Service Unavailable\r\n",
          "504": "HTTP/1.1 504 Gateway Timeout\r\n"
        }

        niech @mime = {
          ".html": "text/html; charset=utf-8",
          ".htm":  "text/html; charset=utf-8",
          ".css":  "text/css; charset=utf-8",
          ".js":   "application/javascript; charset=utf-8",
          ".mjs":  "application/javascript; charset=utf-8",
          ".json": "application/json; charset=utf-8",
          ".xml":  "application/xml; charset=utf-8",
          ".txt":  "text/plain; charset=utf-8",
          ".md":   "text/markdown; charset=utf-8",
          ".csv":  "text/csv; charset=utf-8",
          ".png":  "image/png",
          ".jpg":  "image/jpeg",
          ".jpeg": "image/jpeg",
          ".gif":  "image/gif",
          ".svg":  "image/svg+xml",
          ".webp": "image/webp",
          ".ico":  "image/x-icon",
          ".woff": "font/woff",
          ".woff2": "font/woff2",
          ".ttf":  "font/ttf",
          ".otf":  "font/otf",
          ".pdf":  "application/pdf",
          ".zip":  "application/zip",
          ".mp4":  "video/mp4",
          ".mp3":  "audio/mpeg",
          ".wav":  "audio/wav"
        }

        niech @metody = {
          "GET": prawda,
          "HEAD": prawda,
          "POST": prawda,
          "PUT": prawda,
          "PATCH": prawda,
          "DELETE": prawda,
          "OPTIONS": prawda
        }
      }

      funkcja statusy() { zwroc @statusy }
      funkcja mime() { zwroc @mime }
      funkcja metody_dozwolone() { zwroc @metody }
    }

    funkcja _instancja() {
      zwroc _Tablice.nowy()
    }

    funkcja status_linia(kod) {
      niech klucz = kod.napis()
      niech t = _instancja().statusy()
      niech linia = t[klucz]
      jesli linia == nic to zwroc "HTTP/1.1 " + klucz + " Unknown\r\n"
      zwroc linia
    }

    funkcja mime_z_rozszerzenia(rozszerzenie) {
      niech t = _instancja().mime()[rozszerzenie.malymi()]
      jesli t == nic to zwroc "application/octet-stream"
      zwroc t
    }

    funkcja czy_dozwolona_metoda(m) {
      zwroc _instancja().metody_dozwolone()[m] == prawda
    }
  }
}