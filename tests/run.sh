#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/sayosign"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cd "$T"
head -c 2000000 /dev/urandom > rnd
{ cat "$ROOT"/core/src/*.c; cat rnd; seq 1 100000; } > big
for l in 1 3 9 19; do
  zstd -q -f -$l big -o big.$l.zst
  "$BIN" zstd big.$l.zst out.$l
  cmp big out.$l
done
echo "zstd ok"
mkdir -p src/a/b && cp big src/a/b/ && echo hi > src/x.txt && chmod +x src/x.txt && ln -s ../x.txt src/a/link
"$BIN" zip src t.zip 2>/dev/null
unzip -tq t.zip
"$BIN" unzip t.zip dst 2>/dev/null
diff -r --no-dereference src dst
echo "zip ok"
mkdir -p deb/data/Library/MobileSubstrate/DynamicLibraries
cp "$BIN" deb/data/Library/MobileSubstrate/DynamicLibraries/Test.dylib
(cd deb/data && tar cf ../data.tar .)
zstd -q deb/data.tar -o deb/data.tar.zst
echo "2.0" > deb/debian-binary
(cd deb && tar czf control.tar.gz debian-binary && ar rc ../t.deb debian-binary control.tar.gz data.tar.zst)
"$BIN" deb t.deb debout | grep -q "Test.dylib"
echo "deb ok"
cc -O2 -I"$ROOT/core/include" "$ROOT/tests/crypto_test.c" "$ROOT/build/libsayocore.a" -lcrypto -lz -llzma -o crypto_test
./crypto_test > crypto.txt
python3 "$ROOT/tests/crypto_check.py" crypto.txt
echo "all tests passed"
