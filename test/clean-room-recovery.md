# Clean-room recovery drill

- [ ] Use a fresh workstation or ephemeral VM.
- [ ] Install only the pinned Nix/toolchain environment.
- [ ] Obtain recovery identity through the documented audited process.
- [ ] Prove the external organization recovery grantor authenticates without GitHub, WIF, CI, or
      the daily SSO path and can issue/revoke only the reviewed conditional test grant.
- [ ] Locate the primary and replica state buckets without relying on production services.
- [ ] Restore a noncurrent state object into an isolated test prefix.
- [ ] Run `terraform plan -lock-timeout=20m` and explain every difference.
- [ ] Verify GitHub WIF provider and service-account bindings.
- [ ] Verify `github-config` and `infrastructure-live` can authenticate.
- [ ] Revoke temporary access and record findings.
