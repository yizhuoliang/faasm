from http.server import BaseHTTPRequestHandler, HTTPServer

counter = [0]  # Using a list to maintain state across requests

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        counter[0] += 1
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.write(str(counter[0]).encode())

if __name__ == "__main__":
    server_address = ("", 1081)
    httpd = HTTPServer(server_address, Handler)
    print("Starting server on port 1081...")
    httpd.serve_forever()
