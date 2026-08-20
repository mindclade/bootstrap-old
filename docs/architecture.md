# Bootstrap architecture

`bootstrap` is deliberately smaller than the normal infrastructure control plane.

```text
founder/recovery identity
        -> bootstrap state + GitHub WIF
        -> github-config
        -> infrastructure-live
        -> gitops
```

The repository creates two seed projects: one for state/automation accounts and one for WIF
providers. Normal organization governance is transferred to `infrastructure-live`.
