#!/usr/bin/env python3
"""Find the embedded Psiphon config of an official hiddify-core build, to link the same values
into a rebuilt core.

The official core is linked with two -X strings (see hiddify-core's Makefile):
  github.com/sagernet/sing-box/hiddify/secret.Key              (base64 AES-256 key)
  github.com/sagernet/sing-box/protocol/psiphon.embeddedHiddifyConfig  (base64 encrypted config)
This finds Go string headers (pointer, length) in the library whose bytes are base64, and keeps
the key / ciphertext pair that opens (AES-GCM with the "henc:" marker, as secret.TryDecrypt does).
The config is never written out in plain text: only the two strings, exactly as they are in the
official binary, are written to the output files, for the -X flags of the rebuilt core.

usage: extract_embedded.py libhiddify-core.so KEY_OUT CONFIG_OUT
"""
import base64
import re
import struct
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection

B64 = re.compile(rb"^[A-Za-z0-9+/]+={0,2}$")
MARKER = b"henc:"


def main():
    path, key_out, cfg_out = sys.argv[1:4]
    data = open(path, "rb").read()
    elf = ELFFile(open(path, "rb"))
    segs = [(s["p_vaddr"], s["p_filesz"], s["p_offset"]) for s in elf.iter_segments() if s["p_type"] == "PT_LOAD"]

    def v2o(v):
        for va, sz, off in segs:
            if va <= v < va + sz:
                return off + (v - va)
        return None

    # pointers in the data sections are RELATIVE relocations in a shared library
    ptr_at = {}
    for sec in elf.iter_sections():
        if isinstance(sec, RelocationSection) and sec.is_RELA():
            for r in sec.iter_relocations():
                if r["r_info_type"] in (1027, 8, 23):  # R_AARCH64_RELATIVE, R_X86_64_RELATIVE, R_ARM_RELATIVE
                    ptr_at[r["r_offset"]] = r["r_addend"]
    keys, blobs = set(), set()
    for where, ptr in ptr_at.items():
        o = v2o(where + 8)
        if o is None or o + 8 > len(data):
            continue
        (n,) = struct.unpack_from("<Q", data, o)
        if not (n == 44 or (200 <= n <= 4_000_000 and n % 4 == 0)):
            continue
        so = v2o(ptr)
        if so is None:
            continue
        s = data[so:so + n]
        if len(s) != n or not B64.match(s):
            continue
        (keys if n == 44 else blobs).add(s)
    print(f"candidates: {len(keys)} keys, {len(blobs)} blobs", file=sys.stderr)
    for k in keys:
        try:
            kb = base64.b64decode(k)
        except Exception:
            continue
        if len(kb) != 32:
            continue
        gcm = AESGCM(kb)
        for b in blobs:
            sealed = base64.b64decode(b)
            if len(sealed) < 28:
                continue
            try:
                opened = gcm.decrypt(sealed[:12], sealed[12:], None)
            except Exception:
                continue
            if opened.startswith(MARKER):
                open(key_out, "wb").write(k)
                open(cfg_out, "wb").write(b)
                print(f"found: key 44 chars, config {len(b)} chars (plain {len(opened) - len(MARKER)} bytes)", file=sys.stderr)
                return 0
    print("no embedded config found", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
