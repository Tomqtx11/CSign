"""Exercise the production C++ signer with an ephemeral test identity (never an Apple identity)."""
import base64
import hashlib
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(*args):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


class SigningRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="csign-signing-test-")
        cls.work = pathlib.Path(cls.temp.name)
        cls.probe = cls.work / "signer"
        sources = ["archo", "bundle", "macho", "openssl", "signing"]
        common = ["base64", "fs", "json", "log", "sha", "timer", "util"]
        run("c++", "-std=c++17", "-O1", "-Wno-deprecated-declarations",
            "-I" + str(ROOT / "Zsign/src"), "-I" + str(ROOT / "Zsign/src/common"),
            str(ROOT / "Tests/zsign_probe.cpp"),
            *[str(ROOT / f"Zsign/src/{name}.cpp") for name in sources],
            *[str(ROOT / f"Zsign/src/common/{name}.cpp") for name in common],
            "-lssl", "-lcrypto", "-o", str(cls.probe))
        cls.key = cls.work / "key.pem"
        cert = cls.work / "cert.pem"
        run("openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", str(cls.key), "-out", str(cert), "-days", "1",
            "-subj", "/CN=CSign Regression Test")
        der = run("openssl", "x509", "-in", str(cert), "-outform", "DER").stdout
        cls.p12 = cls.work / "test.p12"
        run("openssl", "pkcs12", "-export", "-inkey", str(cls.key), "-in", str(cert),
            "-out", str(cls.p12), "-passout", "pass:test-password")
        profile = cls.work / "profile.plist"
        profile.write_bytes(plistlib.dumps({
            "TeamIdentifier": ["TESTTEAM01"], "DeveloperCertificates": [der],
            "Entitlements": {"application-identifier": "TESTTEAM01.*", "com.apple.developer.team-identifier": "TESTTEAM01"}
        }))
        cls.provision = cls.work / "test.mobileprovision"
        run("openssl", "cms", "-sign", "-nodetach", "-binary", "-in", str(profile),
            "-signer", str(cert), "-inkey", str(cls.key), "-outform", "DER", "-out", str(cls.provision))

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def make_app(self, name):
        app = self.work / (name + ".app")
        app.mkdir()
        (app / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "com.example.csign.regression", "CFBundleName": "Regression",
            "CFBundleExecutable": "Demo", "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0"
        }))
        shutil.copy2(ROOT / "Zsign/test/dylib/bin/demo1.dylib", app / "Demo")
        (app / ".hidden-resource").write_bytes(b"hidden resources must survive signing")
        return app

    def sign(self, app, remove=False, password="test-password"):
        return subprocess.run([str(self.probe), str(app), str(self.p12), str(self.provision), password,
                               "remove" if remove else "keep"], capture_output=True)

    def test_default_keeps_profile_and_seals_hidden_resources(self):
        app = self.make_app("Default")
        result = self.sign(app)
        self.assertEqual(result.returncode, 0, result.stdout.decode() + result.stderr.decode())
        self.assertEqual((app / "embedded.mobileprovision").read_bytes(), self.provision.read_bytes())
        resources = plistlib.loads((app / "_CodeSignature/CodeResources").read_bytes())
        self.assertIn("embedded.mobileprovision", resources["files"])
        self.assertEqual(resources["files"][".hidden-resource"], hashlib.sha1((app / ".hidden-resource").read_bytes()).digest())

    def test_explicit_removal_omits_profile_and_its_resource_hash(self):
        app = self.make_app("Remove")
        result = self.sign(app, remove=True)
        self.assertEqual(result.returncode, 0, result.stdout.decode() + result.stderr.decode())
        self.assertFalse((app / "embedded.mobileprovision").exists())
        resources = plistlib.loads((app / "_CodeSignature/CodeResources").read_bytes())
        self.assertNotIn("embedded.mobileprovision", resources["files"])

    def test_wrong_password_fails(self):
        app = self.make_app("BadPassword")
        self.assertNotEqual(self.sign(app, password="wrong").returncode, 0)
        self.assertFalse((app / "_CodeSignature/CodeResources").exists())


if __name__ == "__main__":
    unittest.main()
