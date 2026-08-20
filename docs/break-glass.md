# Break-glass

Emergency access to recover the Google Cloud control plane. The service account has **no
standing organization permissions**. Named humans may impersonate it, every use generates a
critical alert, and any temporary grant must expire.

## Use only when

- WIF failure prevents the normal protected apply path from authenticating.
- State/KMS/IAM damage prevents ordinary recovery identities from repairing Ring 0.
- A normal organization policy owned by `infrastructure-live` locks out its own repair path.
- Incident containment requires a permission no standing identity holds.

Being in a hurry is not a break-glass condition.

## Procedure

### 1. Declare the incident

Record the incident ID, failure, intended grant, exact scope, expected duration, and recovery
owner before elevation. Two people participate whenever staffing permits: operator and watcher.

### 2. Grant the narrowest time-bound role

```sh
ORG_ID="..."
BG="$(terraform output -raw break_glass_account)"
EXPIRY="$(date -u -d '+1 hour' '+%Y-%m-%dT%H:%M:%SZ')" # GNU date

gcloud organizations add-iam-policy-binding "$ORG_ID" \
  --member="serviceAccount:${BG}" \
  --role="<narrow-role>" \
  --condition="expression=request.time < timestamp('${EXPIRY}'),title=break-glass-INC-XXXX,description=Incident INC-XXXX"
```

Use organization administrator only when no narrower role can recover the incident.

### 3. Impersonate and perform the minimum repair

```sh
gcloud config set auth/impersonate_service_account "$BG"
# Perform only the declared recovery operations.
gcloud config unset auth/impersonate_service_account
```

Maintain a contemporaneous incident log.

### 4. Revoke immediately

Do not rely on expiry as the normal revocation path. Remove the exact conditional binding and
verify no grant remains.

### 5. Review within 24 hours

Retrieve Cloud Audit Logs for impersonation and actions by the break-glass account. Confirm:

1. the exact resources changed;
2. no action exceeded declared scope;
3. why the normal path failed;
4. which permanent fix removes the need next time;
5. temporary grants are gone;
6. any exposed recovery material was rotated.

`infrastructure-live` owns centralized long-term audit exports. The bootstrap seed project owns
the immediate Cloud Monitoring notification and source Cloud Audit Logs needed before that
normal logging plane is available.

## Drills

Exercise the path at least twice per year using a harmless, five-minute role. Verify:

- impersonation succeeds for an authorized named human;
- the critical notification arrives;
- Cloud Audit Logs contain token exchange and actions;
- the conditional grant expires and is explicitly removed;
- unauthorized principals cannot impersonate the account.

Record drill evidence in the approved incident/recovery system.
