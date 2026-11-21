import hashlib
import hmac
import sys

lines = open(sys.argv[1]).read().splitlines()
for l in lines:
    if l.startswith(("CBC", "GCM")) and not l.endswith("ok=1"):
        sys.exit("FAIL " + l)
d = dict(l.split("=", 1) for l in lines if "=" in l and not l.startswith(("CBC", "GCM")))
N = int(
    "AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50E8083969EDB767B0CF6095179A163AB3661A05FBD5FAAAE82918A9962F0B93B855F97993EC975EEAA80D740ADBF4FF747359D041D5C33EA71D281E446B14773BCA97B43A23FB801676BD207A436C6481F1D2B9078717461A5B9D32E688F87748544523B524B0D57D5EA77A2775D2ECFA032CFBDBF52FB3786160279004E57AE6AF874E7303CE53299CCC041C7BC308D82A5698F3A8D0C38271AE35F8E9DBFBB694B5C803D89F7AE435DE236D525F54759B65E372FCD68EF20FA7111F9E4AFF73",
    16,
)
g = 2


def H(*a):
    return hashlib.sha256(b"".join(a)).digest()


def b(n, l=None):
    return n.to_bytes(l or (n.bit_length() + 7) // 8, "big")


a = int.from_bytes(bytes((i * 7 + 3) & 255 for i in range(32)), "big")
A = pow(g, a, N)
assert b(A, 256).hex() == d["A"]
salt = bytes(range(1, 17))
pk = hashlib.pbkdf2_hmac("sha256", b"pass", salt, 1000, 32)
assert pk.hex() == d["PK"]
Bb = bytearray(255 - i for i in range(256))
Bb[0] = 0x55
B = int.from_bytes(Bb, "big")
k = int.from_bytes(H(b(N), b(g, 256)), "big")
u = int.from_bytes(H(b(A, 256), b(B, 256)), "big")
x = int.from_bytes(H(salt, H(b":", pk)), "big")
S = pow((B - k * pow(g, x, N)) % N, a + u * x, N)
K = H(b(S))
assert K.hex() == d["K"]
M1 = H(bytes(p ^ q for p, q in zip(H(b(N)), H(b(g)))), H(b"user@x.com"), salt, b(A), b(B), K)
assert M1.hex() == d["M1"]
assert H(b(A), M1, K).hex() == d["M2"]
assert hmac.new(b"key", b"msg", hashlib.sha256).hexdigest() == d["HMAC"]
print("crypto ok")
