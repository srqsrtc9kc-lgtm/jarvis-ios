#!/usr/bin/env python3
"""Check the unsigned, thin-arm64 JARVIS IPA without extracting or signing it."""

import argparse
import hashlib
import plistlib
import struct
import sys
import zipfile
from pathlib import Path, PurePosixPath


class ValidationError(ValueError):
    """The artifact does not match the device-build contract."""


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def ios_version(value):
    try:
        parts = tuple(int(part) for part in value.split("."))
    except (AttributeError, ValueError):
        raise ValidationError(f"Invalid iOS version: {value!r}") from None
    require(1 <= len(parts) <= 3 and all(0 <= part <= 255 for part in parts),
            f"Invalid iOS version: {value!r}")
    return parts + (0,) * (3 - len(parts))


def verify_macho(data, expected_minimum):
    require(len(data) >= 32, "Executable has a truncated Mach-O header.")
    magic, cpu, _, filetype, count, command_bytes, _, _ = struct.unpack_from("<8I", data)
    require(magic == 0xFEEDFACF,
            "Expected a thin little-endian 64-bit Mach-O; rebuild with ARCHS=arm64 (fat/universal binaries are unsupported).")
    require(cpu == 0x0100000C, "Executable is not arm64.")
    require(filetype == 2, "Main binary is not a Mach-O executable.")
    end = 32 + command_bytes
    require(end <= len(data) and count <= command_bytes // 8,
            "Mach-O load commands are truncated or malformed.")
    offset = 32
    versions = []
    for _ in range(count):
        require(offset + 8 <= end, "Truncated Mach-O load command.")
        command, size = struct.unpack_from("<2I", data, offset)
        require(size >= 8 and size % 8 == 0 and offset + size <= end,
                "Invalid Mach-O load-command size.")
        if command == 0x32:  # LC_BUILD_VERSION
            require(size >= 24, "Truncated LC_BUILD_VERSION.")
            platform, minimum, _, tools = struct.unpack_from("<4I", data, offset + 8)
            require(size == 24 + 8 * tools, "Invalid LC_BUILD_VERSION tool list.")
            require(platform == 2,
                    f"Mach-O platform is {platform}, not iOS (2); iOS Simulator is 7.")
            versions.append((minimum >> 16, (minimum >> 8) & 255, minimum & 255))
        elif command == 0x1D:  # LC_CODE_SIGNATURE
            raise ValidationError("Executable contains an embedded code signature; expected unsigned output.")
        elif command in (0x21, 0x2C):  # LC_ENCRYPTION_INFO / LC_ENCRYPTION_INFO_64
            require(size >= (24 if command == 0x2C else 20), "Truncated encryption command.")
            cryptid = struct.unpack_from("<I", data, offset + 16)[0]
            require(cryptid == 0, "Executable is encrypted and cannot be used as this unsigned artifact.")
        offset += size
    require(offset == end, "Mach-O command count and size disagree.")
    require(len(versions) == 1, "Expected exactly one LC_BUILD_VERSION for the iOS device binary.")
    require(versions[0] == expected_minimum,
            f"Mach-O minimum iOS {versions[0]} does not match expected {expected_minimum}.")


def verify_ipa(path):
    path = Path(path)
    app = "Payload/JARVIS.app/"
    minimum = ios_version("26.0")
    try:
        with zipfile.ZipFile(path) as archive:
            entries = archive.infolist()
            names = [entry.filename for entry in entries]
            require(len(names) == len(set(names)), "ZIP contains duplicate entry names.")
            for entry in entries:
                parts = PurePosixPath(entry.filename).parts
                require(not entry.filename.startswith("/") and ".." not in parts
                        and "\\" not in entry.filename, "ZIP contains an unsafe path.")
                require(not entry.flag_bits & 1, "ZIP contains encrypted entries.")
                require("_CodeSignature" not in parts and "embedded.mobileprovision" not in parts,
                        "IPA contains a signature/provisioning profile; expected unsigned output.")
            require(archive.testzip() is None, "ZIP integrity check failed.")
            require(app + "Info.plist" in names, "Missing Payload/JARVIS.app/Info.plist.")
            info = plistlib.loads(archive.read(app + "Info.plist"))
            require(isinstance(info, dict), "Info.plist must be a dictionary.")
            require(info.get("DTPlatformName") == "iphoneos", "DTPlatformName is not iphoneos.")
            require(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"],
                    "CFBundleSupportedPlatforms is not [iPhoneOS].")
            require(ios_version(info.get("MinimumOSVersion")) == minimum,
                    "Info.plist minimum iOS must be 26.0.")
            executable = info.get("CFBundleExecutable")
            require(isinstance(executable, str) and executable not in ("", ".", "..")
                    and "/" not in executable and "\\" not in executable,
                    "Invalid CFBundleExecutable in Info.plist.")
            require(app + executable in names, f"Missing executable: {app}{executable}.")
            verify_macho(archive.read(app + executable), minimum)
    except (zipfile.BadZipFile, plistlib.InvalidFileException, KeyError, EOFError, struct.error) as error:
        raise ValidationError(f"Invalid IPA contents: {error}") from None
    digest = hashlib.sha256()
    with path.open("rb") as artifact:
        for chunk in iter(lambda: artifact.read(1024 * 1024), b""):
            digest.update(chunk)
    return {"sha256": digest.hexdigest(), "bundle_id": info.get("CFBundleIdentifier", "(missing)"),
            "executable": executable}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path, help="Path to JARVIS-unsigned.ipa")
    args = parser.parse_args()
    try:
        result = verify_ipa(args.ipa)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"IPA validation failed: {error}", file=sys.stderr)
        return 1
    print(f"Validated: {args.ipa}\nBundle: {result['bundle_id']}\n"
          f"Executable: Payload/JARVIS.app/{result['executable']}\n"
          "Target: iPhoneOS, arm64, minimum iOS 26.0\n"
          "Packaging: unsigned, unencrypted; ZIP integrity verified\n"
          f"SHA256: {result['sha256']}\n"
          "This verifies the artifact only, not signing, installation, or operation on an iPhone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
