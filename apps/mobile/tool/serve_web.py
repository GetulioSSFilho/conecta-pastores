"""Servidor local do build web (flutter build web).

- Fallback SPA: qualquer rota sem arquivo devolve index.html, entao F5 em
  /pastors/123 funciona (em producao, equivalente a `try_files $uri /index.html` no nginx).
- Sem cache para index.html, flutter_bootstrap.js e flutter_service_worker.js:
  evita o navegador servir fontes/JS de builds antigos (causa dos icones "quadrados").

Uso: python tool/serve_web.py [porta]   (padrao 8080)
"""
import functools
import http.server
import os
import socketserver
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
NO_CACHE = {"/", "/index.html", "/flutter_bootstrap.js", "/flutter_service_worker.js", "/manifest.json"}


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        if self.path.split("?")[0] in NO_CACHE:
            self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def send_head(self):
        path = self.translate_path(self.path.split("?")[0])
        if not os.path.exists(path):
            self.path = "/index.html"
        return super().send_head()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    handler = functools.partial(SpaHandler, directory=os.path.abspath(ROOT))
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("0.0.0.0", port), handler) as httpd:
        print(f"Servindo {os.path.abspath(ROOT)} em http://localhost:{port}")
        httpd.serve_forever()
