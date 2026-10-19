#!/usr/bin/env python3
"""Extract embedded screenshots from an xcresult bundle's Data blobs."""
import zstandard, gzip, os, glob, sys

bundle = sys.argv[1]
outdir = sys.argv[2] if len(sys.argv) > 2 else "/tmp/uishots"
os.makedirs(outdir, exist_ok=True)
dctx = zstandard.ZstdDecompressor()
found = 0
for f in sorted(glob.glob(bundle + "/Data/data.0~*"), key=os.path.getsize, reverse=True):
    try:
        out = dctx.stream_reader(open(f, "rb")).read(150_000_000)
    except Exception:
        continue
    if out[:2] == b"\x1f\x8b":
        try:
            out = gzip.decompress(out)
        except Exception:
            continue
    # carve every embedded PNG
    start = 0
    while True:
        idx = out.find(b"\x89PNG\r\n\x1a\n", start)
        if idx < 0:
            break
        # PNG ends with IEND chunk: find IEND + 4 CRC bytes
        end = out.find(b"IEND", idx)
        if end > idx:
            blob = out[idx:end + 8]
            if len(blob) > 50_000:  # skip tiny icons
                open(f"{outdir}/shot{found}.png", "wb").write(blob)
                print(f"{outdir}/shot{found}.png", len(blob))
                found += 1
        start = (end if end > idx else idx) + 4
        if found > 20:
            break
print("found", found)
