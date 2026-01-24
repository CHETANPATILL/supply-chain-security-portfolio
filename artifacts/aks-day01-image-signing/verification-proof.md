# Image Signature Verification - Day 1 AKS

**Date**: Sat Jan 24 15:08:58 IST 2026
**Image**: chetandevsecops.azurecr.io/myapp:v1
**Digest**: sha256:6378e2f6de33ffb70c9375707a9b342f7fcd6aaad65eca27419e1ffb758c9c0d

## Verification Command
```bash
cosign verify --key cosign.pub chetandevsecops.azurecr.io/myapp:v1
```

## Result
✅ Signature verified successfully

## Public Key
```
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhtIhKZ2zsiUccGdyChRngP978o8y
J+ZlphLPUTa7Og4iqQzl1yaz/Zi7o5ewE3Tw1zlXm8I1KCmLL66jpq3PtA==
-----END PUBLIC KEY-----
```

## Signature Metadata
See: image-metadata.json
