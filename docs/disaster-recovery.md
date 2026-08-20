# Ring-0 disaster recovery

Recovery order:

1. recover GitHub Enterprise, Cloud Identity, billing, and registrar ownership;
2. activate audited break-glass access;
3. restore or locate bootstrap GCS state from version history/replica;
4. verify state with a read-only plan;
5. recover WIF and automation service accounts;
6. recover `github-config` and `infrastructure-live`;
7. rebuild cloud layers and then re-bootstrap Argo CD.

Recovery must not depend on GKE, Argo CD, Cloud SQL, or an application workload.
