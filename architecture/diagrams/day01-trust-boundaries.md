# Supply Chain Trust Boundaries
```
┌─────────────┐      ┌─────────┐      ┌─────────┐      ┌──────────┐      ┌────────────┐
│  Developer  │─────▶│   Git   │─────▶│  CI/CD  │─────▶│ Registry │─────▶│ Kubernetes │
│   Laptop    │      │ (GitHub)│      │ (Build) │      │ (Images) │      │  Cluster   │
└─────────────┘      └─────────┘      └─────────┘      └──────────┘      └────────────┘
      │                    │                │                 │                  │
      ▼                    ▼                ▼                 ▼                  ▼
   [Risk:]            [Risk:]          [Risk:]           [Risk:]            [Risk:]
  Malware           Stolen creds     Compromised       Registry hack      Unsigned
  on laptop         bad commits      build env         image swap         image runs

      │                    │                │                 │                  │
      ▼                    ▼                ▼                 ▼                  ▼
 [Control:]          [Control:]        [Control:]        [Control:]         [Control:]
  Signed             Signed            Image             Image              Admission
  commits            commits           signing           signing            control
                                                        + transparency      enforcement
```

**Trust Boundary**: Each arrow (→) is a point where control changes hands.

**Defense in Depth**: Multiple controls at each boundary.
