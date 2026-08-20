# Cold-start recovery

1. Recover GitHub Enterprise, Cloud Identity, billing, and Squarespace registrar ownership.
2. Activate the audited break-glass path.
3. Locate the primary or replica bootstrap state bucket.
4. Restore state to an isolated object/prefix and inspect it.
5. Recover bootstrap WIF and automation accounts.
6. Recover `github-config`.
7. Rebuild `infrastructure-live` in layer order.
8. Install Argo CD from `gitops/bootstrap` and apply the root application.
9. Let GitOps reconcile; then restore stateful application data.

Never make recovery depend on the failed Kubernetes runtime.
