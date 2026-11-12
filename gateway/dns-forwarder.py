#!/usr/bin/env python3
"""Forward UDP/TCP DNS over TCP through tun0, never Docker's host resolver."""
import concurrent.futures
import contextlib
import socket
import socketserver
import struct
import threading


def read_exact(stream, count):
    data = b""
    while len(data) < count:
        chunk = stream.recv(count - len(data))
        if not chunk:
            raise ConnectionError("Truncated DNS response")
        data += chunk
    return data


def resolve(query):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as upstream:
        upstream.settimeout(8)
        upstream.setsockopt(socket.SOL_SOCKET, socket.SO_MARK, 53)
        upstream.connect(("1.1.1.1", 53))
        upstream.sendall(struct.pack("!H", len(query)) + query)
        size = struct.unpack("!H", read_exact(upstream, 2))[0]
        return read_exact(upstream, size)


class UDPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        query, server = self.request
        # Fail closed; never fall back to host DNS.
        with contextlib.suppress(OSError, ConnectionError):
            server.sendto(resolve(query), self.client_address)


class TCPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(10)
        with contextlib.suppress(OSError, ConnectionError):
            size = struct.unpack("!H", read_exact(self.request, 2))[0]
            answer = resolve(read_exact(self.request, size))
            self.request.sendall(struct.pack("!H", len(answer)) + answer)


class BoundedThreads(socketserver.ThreadingMixIn, socketserver.BaseServer):
    # Limit aggregate in-flight DNS work; excess requests fail closed.
    slots = threading.BoundedSemaphore(64)
    daemon_threads = True

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()


class UDPServer(BoundedThreads, socketserver.UDPServer):
    allow_reuse_address = True


class TCPServer(BoundedThreads, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    with UDPServer(("127.0.0.1", 1053), UDPHandler) as udp, \
            TCPServer(("127.0.0.1", 1053), TCPHandler) as tcp, \
            concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(server.serve_forever) for server in (udp, tcp)]
        for future in concurrent.futures.as_completed(futures):
            future.result()
            raise RuntimeError("DNS listener stopped")
