#!/usr/bin/env python3
"""Exercise the packaged launcher with host-built OpenSSH, over local pipes.

This verifies SFTP transfers and transport selection, not an SSH handshake or
PPC execution. Usage: python3 tests/test_sftp_transfer.py CLIENT SERVER
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
client, server = (Path(arg).resolve() for arg in sys.argv[1:])
with tempfile.TemporaryDirectory(prefix="weazlterm-sftp-") as temporary:
    base = Path(temporary)
    helpers = base / "USB folder" / "weazlterm.app" / "Contents" / "Helpers"
    helpers.mkdir(parents=True)
    shutil.copy2(root / "resources/helpers/sftp", helpers / "sftp")
    (helpers / "sftp").chmod(0o755)
    shutil.copy2(client, helpers / "sftp-client")
    transport = helpers / "ssh"
    transport.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$WT_TRANSPORT_LOG"\n'
                         'exec "$WT_TEST_SERVER" -e\n')
    transport.chmod(0o755)
    source = base / "upload payload.bin"
    remote = base / "remote payload.bin"
    download = base / "download payload.bin"
    source.write_bytes(bytes(range(256)) * 4096)
    batch = base / "commands.txt"
    batch.write_text(f'put "{source}" "{remote}"\n'
                     f'get "{remote}" "{download}"\nquit\n')
    env = dict(os.environ, WT_TEST_SERVER=str(server),
               WT_TRANSPORT_LOG=str(base / "transport.log"))
    result = subprocess.run([str(helpers / "sftp"), "-b", str(batch), "user@fixture"],
                            env=env, cwd="/", capture_output=True, timeout=20)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    assert source.read_bytes() == remote.read_bytes() == download.read_bytes()
    assert "sftp" in (base / "transport.log").read_text().splitlines()
    batch.write_text(f'get "{base / "missing"}" "{base / "unexpected"}"\n')
    result = subprocess.run([str(helpers / "sftp"), "-b", str(batch), "user@fixture"],
                            env=env, cwd="/", capture_output=True, timeout=20)
    assert result.returncode != 0
    assert not (base / "unexpected").exists()
print("sftp: 1 MiB binary put/get, spaced relocation, bundled transport, batch failure passed")
