"""Run the production IPA endpoint over real HTTP and verify probes, resume and ZIP bytes."""
import hashlib
import io
import os
import pathlib
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import json
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix="csign-http-test-") as directory:
    work = pathlib.Path(directory)
    sources = work / "Sources/Harness"
    sources.mkdir(parents=True)
    (work / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "HTTPRegression", platforms: [.macOS(.v12)],
    products: [.executable(name: "Harness", targets: ["Harness"])],
    dependencies: [.package(url: "https://github.com/vapor/vapor", exact: "4.104.0")],
    targets: [.executableTarget(name: "Harness", dependencies: [.product(name: "Vapor", package: "vapor")])])
''')
    shutil.copy2(ROOT / "CSign.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved", work / "Package.resolved")
    shutil.copy2(ROOT / "CSign/Backend/Server/InstallationPayload.swift", sources / "InstallationPayload.swift")
    shutil.copy2(ROOT / "CSign/Utilities/PayloadTransferTracker.swift", sources / "PayloadTransferTracker.swift")
    (sources / "main.swift").write_text('''import Foundation
import Vapor

final class Counts: @unchecked Sendable {
    private let lock = NSLock()
    private var starts = 0
    private var completions = 0
    func started() { lock.lock(); starts += 1; lock.unlock() }
    func completed(_ progress: PayloadTransferTracker.Progress) {
        lock.lock(); if progress.isComplete { completions += 1 }; lock.unlock()
    }
    func json(_ tracker: PayloadTransferTracker) -> String {
        let state = tracker.snapshot
        lock.lock(); defer { lock.unlock() }
        let fields: [String: Any] = ["starts": starts, "completions": completions,
            "bytes": state.bytes, "total": state.total, "complete": state.isComplete]
        return String(data: try! JSONSerialization.data(withJSONObject: fields), encoding: .utf8)!
    }
}

let file = URL(fileURLWithPath: CommandLine.arguments[1])
let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as! NSNumber).int64Value
let tracker = PayloadTransferTracker(size: size)
let fresh = PayloadTransferTracker(size: size)
let counts = Counts()
let freshCounts = Counts()
let app = Application(.testing)
app.http.server.configuration.hostname = "127.0.0.1"
app.http.server.configuration.port = Int(CommandLine.arguments[2])!
app.get("payload.ipa") { req -> Response in
    InstallationPayload.response(to: req, file: file, tracker: tracker,
        onStarted: { counts.started() }, onProgress: { _ in },
        onCompleted: { counts.completed($0) })
}
app.get("fresh.ipa") { req -> Response in
    InstallationPayload.response(to: req, file: file, tracker: fresh,
        onStarted: { freshCounts.started() }, onProgress: { _ in },
        onCompleted: { freshCounts.completed($0) })
}
app.get("missing.ipa") { req -> Response in
    InstallationPayload.response(to: req, file: file.appendingPathExtension("missing"), tracker: tracker,
        onStarted: { counts.started() }, onProgress: { _ in },
        onCompleted: { counts.completed($0) })
}
app.get("state") { _ in counts.json(tracker) }
app.get("fresh-state") { _ in freshCounts.json(fresh) }
try app.server.start()
RunLoop.main.run()
''')
    print("Building the production HTTP endpoint harness", flush=True)
    result = subprocess.run(["swift", "build", "--package-path", str(work)], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    fixture = work / "Archive.ipa"
    with zipfile.ZipFile(fixture, "w", compression=zipfile.ZIP_STORED) as archive:
        archive.writestr("Payload/Demo.app/Info.plist", b"test plist")
        archive.writestr("Payload/Demo.app/Demo", os.urandom(8 * 1024 * 1024))
        archive.writestr("Payload/Demo.app/embedded.mobileprovision", b"test profile")
    original = fixture.read_bytes()
    size = len(original)
    with socket.socket() as reserved:
        reserved.bind(("127.0.0.1", 0))
        port = reserved.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    # Avoid the runner's HTTP proxy for loopback requests, as on the device.
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def request(path, method="GET", headers=None):
        with client.open(urllib.request.Request(base + path, method=method, headers=headers or {}), timeout=20) as response:
            return response.status, response.headers, response.read()

    def state(path="/state"):
        return json.loads(request(path)[2])

    def wait_for(expected, path="/state"):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            current = state(path)
            if all(current[key] == value for key, value in expected.items()):
                return current
            time.sleep(0.02)
        raise AssertionError((expected, current))

    with (work / "server.log").open("w+") as log:
        server = subprocess.Popen([str(work / ".build/debug/Harness"), str(fixture), str(port)], stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 30
            while True:
                try:
                    state()
                    break
                except (urllib.error.URLError, TimeoutError):
                    if server.poll() is not None or time.monotonic() >= deadline:
                        log.seek(0)
                        raise RuntimeError(log.read())
                    time.sleep(0.1)

            status, headers, body = request("/payload.ipa", "HEAD", {"Range": "bytes=0-1"})
            assert status == 200 and len(body) == 0
            assert int(headers["Content-Length"]) == size
            assert headers["Accept-Ranges"] == "bytes"
            wait_for({"starts": 0, "completions": 0, "bytes": 0})

            _, _, first = request("/payload.ipa", headers={"Range": "bytes=0-127"})
            assert first == original[:128]
            wait_for({"bytes": 128, "complete": False, "completions": 0})
            status, headers, prefix = request("/payload.ipa", headers={"Range": "bytes=0-255"})
            assert status == 206 and headers["Content-Range"] == f"bytes 0-255/{size}"
            assert prefix == original[:256]
            wait_for({"bytes": 256, "complete": False, "completions": 0})
            _, _, suffix = request("/payload.ipa", headers={"Range": "bytes=-128"})
            assert suffix == original[-128:]
            wait_for({"bytes": 384, "complete": False, "completions": 0})

            for invalid in [f"bytes={size}-", "bytes=10-1", "bytes=0-1,5-6"]:
                try:
                    request("/payload.ipa", headers={"Range": invalid})
                    raise AssertionError("Invalid range must not stream an IPA")
                except urllib.error.HTTPError as error:
                    assert error.code == 416 and error.headers["Content-Range"] == f"bytes */{size}"
            wait_for({"starts": 3, "bytes": 384, "completions": 0})

            _, _, middle = request("/payload.ipa", headers={"Range": f"bytes=256-{size - 129}"})
            reconstructed = prefix + middle + suffix
            assert hashlib.sha256(reconstructed).digest() == hashlib.sha256(original).digest()
            assert zipfile.ZipFile(io.BytesIO(reconstructed)).testzip() is None
            wait_for({"bytes": size, "complete": True, "completions": 1})

            status, headers, full = request("/fresh.ipa")
            assert status == 200 and int(headers["Content-Length"]) == size
            assert headers["Content-Type"] == "application/octet-stream"
            assert full == original
            wait_for({"bytes": size, "complete": True, "completions": 1}, "/fresh-state")
            try:
                request("/missing.ipa")
                raise AssertionError("Missing IPA must fail")
            except urllib.error.HTTPError as error:
                assert error.code == 404
            print("PASS: real HTTP HEAD does not install, ranges resume without double counting, invalid ranges fail, and complete IPA bytes/CRC match", flush=True)
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
