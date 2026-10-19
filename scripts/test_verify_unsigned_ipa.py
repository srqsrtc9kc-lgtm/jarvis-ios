"""Synthetic artifacts exercise checks that distinguish device and simulator builds."""

import hashlib
import plistlib
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_unsigned_ipa import ValidationError, verify_ipa


def macho(platform=2, minimum=26 << 16, cpu=0x0100000C, extra=b""):
    command = struct.pack("<6I", 0x32, 24, platform, minimum, 26 << 16, 0)
    commands = command + extra
    return struct.pack("<8I", 0xFEEDFACF, cpu, 0, 2, 1 + bool(extra), len(commands), 0, 0) + commands


class VerifyIPATests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "JARVIS.ipa"

    def create(self, binary=None, metadata=None, additional=None):
        info = {"DTPlatformName": "iphoneos", "CFBundleSupportedPlatforms": ["iPhoneOS"],
                "MinimumOSVersion": "26.0", "CFBundleExecutable": "JARVIS",
                "CFBundleIdentifier": "com.jarviskoc.local"}
        info.update(metadata or {})
        with zipfile.ZipFile(self.path, "w") as archive:
            archive.writestr("Payload/JARVIS.app/Info.plist", plistlib.dumps(info))
            archive.writestr("Payload/JARVIS.app/JARVIS", macho() if binary is None else binary)
            for name, data in (additional or {}).items():
                archive.writestr(name, data)
        return self.path

    def test_valid_device_ipa_and_digest(self):
        self.create()
        result = verify_ipa(self.path)
        self.assertEqual(result["sha256"], hashlib.sha256(self.path.read_bytes()).hexdigest())
        self.assertEqual(result["executable"], "JARVIS")

    def test_arm64_simulator_rejected_even_with_device_plist(self):
        self.create(binary=macho(platform=7))
        with self.assertRaisesRegex(ValidationError, "platform is 7"):
            verify_ipa(self.path)

    def test_simulator_metadata_rejected(self):
        self.create(metadata={"DTPlatformName": "iphonesimulator"})
        with self.assertRaisesRegex(ValidationError, "DTPlatformName"):
            verify_ipa(self.path)

    def test_profile_and_signature_directory_rejected(self):
        for marker in ("embedded.mobileprovision", "_CodeSignature/CodeResources"):
            with self.subTest(marker=marker):
                self.create(additional={"Payload/JARVIS.app/" + marker: b"signature"})
                with self.assertRaisesRegex(ValidationError, "signature/provisioning"):
                    verify_ipa(self.path)

    def test_embedded_binary_signature_rejected(self):
        self.create(binary=macho(extra=struct.pack("<4I", 0x1D, 16, 0, 0)))
        with self.assertRaisesRegex(ValidationError, "embedded code signature"):
            verify_ipa(self.path)

    def test_encrypted_binary_rejected(self):
        self.create(binary=macho(extra=struct.pack("<6I", 0x2C, 24, 0, 0, 1, 0)))
        with self.assertRaisesRegex(ValidationError, "encrypted"):
            verify_ipa(self.path)

    def test_wrong_architecture_and_minimum_rejected(self):
        for binary, message in ((macho(cpu=0x01000007), "not arm64"),
                                (macho(minimum=25 << 16), "minimum iOS")):
            with self.subTest(message=message):
                self.create(binary=binary)
                with self.assertRaisesRegex(ValidationError, message):
                    verify_ipa(self.path)

    def test_wrong_plist_minimum_rejected(self):
        self.create(metadata={"MinimumOSVersion": "25.0"})
        with self.assertRaisesRegex(ValidationError, "minimum iOS"):
            verify_ipa(self.path)

    def test_malformed_zip_rejected(self):
        self.path.write_bytes(b"not a ZIP")
        with self.assertRaisesRegex(ValidationError, "Invalid IPA"):
            verify_ipa(self.path)

    def test_truncated_header_and_command_rejected(self):
        for binary in (b"short", macho()[:-1]):
            with self.subTest(binary=binary):
                self.create(binary=binary)
                with self.assertRaisesRegex(ValidationError, "truncated"):
                    verify_ipa(self.path)

    def test_unsupported_universal_binary_rejected(self):
        self.create(binary=b"\xca\xfe\xba\xbe" + bytes(60))
        with self.assertRaisesRegex(ValidationError, "fat/universal"):
            verify_ipa(self.path)

    def test_missing_executable_rejected(self):
        self.create(metadata={"CFBundleExecutable": "Missing"})
        with self.assertRaisesRegex(ValidationError, "Missing executable"):
            verify_ipa(self.path)


if __name__ == "__main__":
    unittest.main()
