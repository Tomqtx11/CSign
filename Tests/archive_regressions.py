"""Build the production IPA writer against the same Zip dependency, then inspect real archives."""
import hashlib
import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix="csign-archive-test-") as directory:
    work = pathlib.Path(directory)
    sources = work / "Sources/Harness"
    sources.mkdir(parents=True)
    (work / "Package.swift").write_text('''// swift-tools-version: 5.8
import PackageDescription
let package = Package(name: "ArchiveRegression", products: [.executable(name: "Harness", targets: ["Harness"])],
    dependencies: [.package(url: "https://github.com/marmelroy/Zip", exact: "2.1.2")],
    targets: [.executableTarget(name: "Harness", dependencies: [.product(name: "Zip", package: "Zip")])])
''')
    shutil.copy2(ROOT / "CSign/Utilities/IPAArchiveWriter.swift", sources / "IPAArchiveWriter.swift")
    (sources / "main.swift").write_text('''import Foundation
let args = CommandLine.arguments
var values: [Double] = []
try IPAArchiveWriter.write(app: URL(fileURLWithPath: args[1]), to: URL(fileURLWithPath: args[2]),
    compressionLevel: Int32(args[3])!) { values.append($0) }
precondition(values.first == 0 && values.last == 1)
precondition(zip(values, values.dropFirst()).allSatisfy { $0.0 <= $0.1 })
''')
    result = subprocess.run(["swift", "build", "--package-path", str(work), "-c", "release"], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    executable = work / ".build/release/Harness"
    app = work / "Ứng dụng + Test.app"
    framework = app / "Frameworks/Test.framework/Versions/A"
    framework.mkdir(parents=True)
    (framework / "Test").write_bytes(os.urandom(1024 * 1024))
    (app / "Demo").write_bytes(b"test executable")
    (app / "Demo").chmod(0o755)
    (app / "embedded.mobileprovision").write_bytes(b"test provisioning bytes")
    (app / ".hidden-resource").write_bytes(b"hidden bytes")
    (app / "Empty").mkdir()
    (framework.parent / "Current").symlink_to("A", target_is_directory=True)
    (framework.parent.parent / "Test").symlink_to("Versions/Current/Test")
    before = {str(p.relative_to(app)): hashlib.sha256(p.read_bytes()).digest()
              for p in app.rglob("*") if p.is_file() and not p.is_symlink()}
    root = "Payload/" + app.name + "/"
    for level in (0, -1):
        output = work / f"archive-{level}.ipa"
        result = subprocess.run([str(executable), str(app), str(output), str(level)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        with zipfile.ZipFile(output) as archive:
            assert archive.testzip() is None
            assert all(name.startswith(root) for name in archive.namelist())
            assert archive.read(root + "embedded.mobileprovision") == b"test provisioning bytes"
            assert archive.read(root + ".hidden-resource") == b"hidden bytes"
            assert root + "Empty/" in archive.namelist()
            assert stat.S_IMODE(archive.getinfo(root + "Demo").external_attr >> 16) == 0o755
            link = archive.getinfo(root + "Frameworks/Test.framework/Test")
            assert stat.S_ISLNK(link.external_attr >> 16)
            assert archive.read(link) == b"Versions/Current/Test"
            assert stat.S_ISLNK(archive.getinfo(root + "Frameworks/Test.framework/Versions/Current").external_attr >> 16)
            assert archive.getinfo(root + "Demo").compress_type == (zipfile.ZIP_STORED if level == 0 else zipfile.ZIP_DEFLATED)
    after = {str(p.relative_to(app)): hashlib.sha256(p.read_bytes()).digest()
             for p in app.rglob("*") if p.is_file() and not p.is_symlink()}
    assert before == after
    invalid_output = work / "invalid.ipa"
    result = subprocess.run([str(executable), str(work / "Missing.app"), str(invalid_output), "0"], capture_output=True)
    assert result.returncode != 0 and not invalid_output.exists()
    print("PASS: direct IPA packaging, CRC, hidden files, executable modes, Unicode names, symlinks and source preservation")
