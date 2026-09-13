#!/usr/bin/env python3
"""Agent-fed loopback Chat Completions provider. Never evaluates a Learning test."""
import argparse
import json
from pathlib import Path
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

POLL_SECONDS = 0.1
MAX_WAIT_SECONDS = 1800


class Provider(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/v1/chat/completions':
            self.send_error(404)
            return
        with self.server.counter_lock:
            self.server.counter += 1
            number = self.server.counter
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        (self.server.root / f'request-{number:04}.json').write_text(json.dumps(request, indent=2) + '\n')
        response_path = self.server.root / f'response-{number:04}.json'
        deadline = time.monotonic() + MAX_WAIT_SECONDS
        while not response_path.exists():
            if time.monotonic() >= deadline:
                self.send_error(504, 'No scripted response supplied')
                return
            time.sleep(POLL_SECONDS)
        response = json.loads(response_path.read_text())
        time.sleep(response.get('delay_seconds', 0))
        message = response['message']
        finish = 'tool_calls' if message.get('tool_calls') else 'stop'
        common = dict(id=f'fixture-{number}', created=int(time.time()), model='scripted')
        try:
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream' if request.get('stream') else 'application/json')
            self.end_headers()
            if request.get('stream'):
                delta = dict(message)
                if delta.get('tool_calls'):
                    delta['tool_calls'] = [dict(call, index=i) for i, call in enumerate(delta['tool_calls'])]
                for payload in [dict(common, object='chat.completion.chunk', choices=[dict(index=0, delta=delta, finish_reason=None)]), dict(common, object='chat.completion.chunk', choices=[dict(index=0, delta={}, finish_reason=finish)])]:
                    self.wfile.write(('data: ' + json.dumps(payload) + '\n\n').encode())
                self.wfile.write(b'data: [DONE]\n\n')
            else:
                self.wfile.write(json.dumps(dict(common, object='chat.completion', choices=[dict(index=0, message=message, finish_reason=finish)], usage=dict(prompt_tokens=0, completion_tokens=0, total_tokens=0))).encode())
        except (BrokenPipeError, ConnectionResetError):
            (self.server.root / f'disconnected-{number:04}').touch()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    root = args.directory.resolve()
    root.mkdir(parents=True, exist_ok=True)
    if list(root.glob('request-*.json')):
        parser.error('Use a fresh provider directory for every service session')
    server = ThreadingHTTPServer(('127.0.0.1', 0), Provider)
    server.daemon_threads = True
    server.root = root
    server.counter = 0
    server.counter_lock = threading.Lock()
    (root / 'endpoint.json').write_text(json.dumps(dict(baseURL=f'http://127.0.0.1:{server.server_port}/v1', pid=__import__('os').getpid())) + '\n')
    server.serve_forever()
