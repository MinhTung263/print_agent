import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SCRIPT = HERE / "make_release.py"


def run(dist: Path, tag: str, pubspec: Path):
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(dist), tag, "owner/repo", str(pubspec)],
        capture_output=True, text=True,
    )


class MakeRelease(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.dist = self.tmp / "dist"
        self.dist.mkdir()
        (self.dist / "TramInEasyPOS-Setup-0.2.0.exe").write_bytes(b"exe-bytes")
        (self.dist / "easypos-print-agent_0.2.0+3_amd64.deb").write_bytes(b"deb-bytes")
        self.pubspec = self.tmp / "pubspec.yaml"
        self.pubspec.write_text("name: x\nversion: 0.2.0+3\n")

    def test_ok_ghi_ten_co_dinh_va_update_json(self):
        r = run(self.dist, "v0.2.0", self.pubspec)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((self.dist / "TramInEasyPOS-Setup.exe").exists())
        self.assertTrue((self.dist / "easypos-print-agent_amd64.deb").exists())
        m = json.loads((self.dist / "update.json").read_text())
        self.assertEqual((m["version"], m["build"]), ("0.2.0", 3))
        self.assertEqual(
            m["windows"]["url"],
            "https://github.com/owner/repo/releases/download/v0.2.0/TramInEasyPOS-Setup-0.2.0.exe",
        )
        # '+' trong tên .deb phải mã hoá trong URL.
        self.assertIn("0.2.0%2B3_amd64.deb", m["linux"]["url"])
        import hashlib
        self.assertEqual(m["windows"]["sha256"], hashlib.sha256(b"exe-bytes").hexdigest())
        self.assertEqual(m["linux"]["sha256"], hashlib.sha256(b"deb-bytes").hexdigest())

    def test_tag_sai_thi_dung(self):
        r = run(self.dist, "v0.3.0", self.pubspec)
        self.assertEqual(r.returncode, 1)
        self.assertFalse((self.dist / "update.json").exists())

    def test_thieu_tep(self):
        (self.dist / "easypos-print-agent_0.2.0+3_amd64.deb").unlink()
        self.assertEqual(run(self.dist, "v0.2.0", self.pubspec).returncode, 1)

    def test_pubspec_khong_co_build(self):
        self.pubspec.write_text("version: 0.2.0\n")
        r = run(self.dist, "v0.2.0", self.pubspec)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads((self.dist / "update.json").read_text())["build"], 0)


if __name__ == "__main__":
    unittest.main()
