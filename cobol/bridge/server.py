"""ECBS COBOL bridge.

Minimal HTTP service (stdlib only) that exposes the compiled COBOL
programs to the backend. It plays the role that a transaction monitor
(CICS/IMS) would play on a mainframe:

    GET  /health            -> bridge liveness + number of programs
    GET  /programs          -> list of available COBOL programs
    POST /run/<PROGRAM>     -> executes the program; the JSON request
                               body is piped to the program's stdin and
                               its stdout is returned (parsed as JSON
                               when possible).
"""
import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BIN_DIR = os.environ.get("ECBS_BIN_DIR", "/opt/ecbs/bin")
PORT = int(os.environ.get("BRIDGE_PORT", "9090"))
RUN_TIMEOUT_SECONDS = int(os.environ.get("BRIDGE_RUN_TIMEOUT", "60"))
PROGRAM_NAME_RE = re.compile(r"^[A-Z][A-Z0-9-]{0,30}$")


def list_programs():
    if not os.path.isdir(BIN_DIR):
        return []
    return sorted(
        name for name in os.listdir(BIN_DIR)
        if not name.endswith(".so")
        and os.access(os.path.join(BIN_DIR, name), os.X_OK)
    )


def run_program(name, payload):
    """Runs a COBOL binary, piping the JSON payload through stdin."""
    binary = os.path.join(BIN_DIR, name)
    completed = subprocess.run(
        [binary],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        timeout=RUN_TIMEOUT_SECONDS,
        env=os.environ.copy(),
    )
    stdout = completed.stdout.strip()
    result = {
        "program": name,
        "exitCode": completed.returncode,
        "stdout": stdout,
        "stderr": completed.stderr.strip(),
    }
    try:
        result["data"] = json.loads(stdout)
    except (json.JSONDecodeError, ValueError):
        result["data"] = None
    return result


class BridgeHandler(BaseHTTPRequestHandler):
    server_version = "ECBSCobolBridge/1.0"

    def _send_json(self, status, body):
        raw = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == "/health":
            programs = list_programs()
            self._send_json(200, {
                "status": "UP",
                "service": "cobol-bridge",
                "programCount": len(programs),
            })
        elif self.path == "/programs":
            self._send_json(200, {"programs": list_programs()})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        match = re.match(r"^/run/([^/]+)$", self.path)
        if not match:
            self._send_json(404, {"error": "not found"})
            return

        name = match.group(1)
        if not PROGRAM_NAME_RE.match(name) or name not in list_programs():
            self._send_json(404, {"error": f"unknown program: {name}"})
            return

        length = int(self.headers.get("Content-Length") or 0)
        raw_body = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw_body) if raw_body else {}
        except json.JSONDecodeError:
            self._send_json(400, {"error": "request body must be JSON"})
            return

        try:
            self._send_json(200, run_program(name, payload))
        except subprocess.TimeoutExpired:
            self._send_json(504, {"error": f"program {name} timed out"})
        except Exception as exc:  # noqa: BLE001 - report any runtime failure
            self._send_json(500, {"error": str(exc)})

    def log_message(self, fmt, *args):
        print(f"[bridge] {self.address_string()} {fmt % args}", flush=True)


if __name__ == "__main__":
    print(f"[bridge] ECBS COBOL bridge listening on :{PORT}", flush=True)
    print(f"[bridge] programs: {', '.join(list_programs()) or '(none)'}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), BridgeHandler).serve_forever()
