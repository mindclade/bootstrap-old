<!-- mindclade-doc: runbook@1 -->

# Break-glass

> **Use when:** the normal protected recovery path cannot restore Ring 0.
> **Impact:** temporary elevated organization access; every action is incident-scoped and audited.
> **Primary owner:** incident commander and named bootstrap recovery operator.
> **Escalate:** immediately to security and platform leadership on any undeclared or unlogged use.

Emergency access to recover the Google Cloud control plane. The service account has **no
standing organization permissions**. Named humans may impersonate it, every use generates a
critical alert, and any temporary grant must expire.

This service account is an emergency **execution identity**, not the root credential that grants
its own authority. A separately controlled Google Cloud organization recovery grantor must remain
available outside GitHub, WIF, the break-glass service account, and the daily SSO failure domain.
That external grantor needs `resourcemanager.organizations.getIamPolicy` and
`resourcemanager.organizations.setIamPolicy` on the organization. Terraform deliberately does not
create or store that root credential. Without the independently tested external grantor, this
runbook is circular and break-glass is not production-qualified.

## Use only when

- WIF failure prevents the normal protected apply path from authenticating.
- State/KMS/IAM damage prevents ordinary recovery identities from repairing Ring 0.
- A normal organization policy owned by `infrastructure-live` locks out its own repair path.
- Incident containment requires a permission no standing identity holds.

Being in a hurry is not a break-glass condition.

## Before production

- Configure at least one intended named human operator. Terraform validates email syntax only;
  before activation, a Cloud Identity administrator must prove that every configured principal is
  a user and not a group, alias, shared mailbox, or service account.
- Designate the minimum number of external organization recovery grantors. Keep their
  authentication independent of daily SSO, GitHub, WIF, and the break-glass service account;
  require phishing-resistant MFA and store the recovery process in the approved offline vault.
- Prove an external recovery grantor can read and conditionally update organization IAM without
  using GitHub or WIF, then remove the harmless test binding.
- Ensure the security mailbox accepts mail from `alerting-noreply@google.com`.
- Send a test notification and record delivery evidence before relying on the channel.
- Confirm an unauthorized user cannot impersonate the account.
- Confirm the authorized operator can impersonate it without holding any standing organization
  permission through the account.

## Procedure

### 1. Declare the incident

Record the incident ID, failure, intended grant, exact scope, expected duration, and recovery
owner before elevation. Two people participate whenever staffing permits: operator and watcher.

### 2. Grant the narrowest time-bound role

Authenticate as the external organization recovery grantor. Do not impersonate the break-glass
service account to grant its own authority.

```sh
ORG_ID="..."
BG="$(terraform output -raw break_glass_account)"
INCIDENT="INC-XXXX"
ROLE="<narrow-role>"
EXPIRY="$(python3 -c 'from datetime import UTC, datetime, timedelta; print((datetime.now(UTC) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
CONDITION="expression=request.time < timestamp('${EXPIRY}'),title=break-glass-${INCIDENT},description=Incident ${INCIDENT}"

gcloud organizations add-iam-policy-binding "$ORG_ID" \
  --member="serviceAccount:${BG}" \
  --role="${ROLE}" \
  --condition="${CONDITION}"
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

```sh
gcloud organizations remove-iam-policy-binding "$ORG_ID" \
  --member="serviceAccount:${BG}" \
  --role="${ROLE}" \
  --condition="${CONDITION}"

gcloud organizations get-iam-policy "$ORG_ID" --format=json \
  | jq --arg member "serviceAccount:${BG}" \
      '[.bindings[] | select(.members[]? == $member)] | length == 0'
```

The final command must print `true`. Preserve the pre-grant and post-revocation policy etags in
the incident record without publishing the full organization policy.

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

- the external recovery grantor authenticates without daily SSO, GitHub, WIF, or CI;
- impersonation succeeds for an authorized named human;
- the critical notification arrives;
- Cloud Audit Logs contain token exchange and actions;
- the conditional grant expires and is explicitly removed;
- unauthorized principals cannot impersonate the account.

Record drill evidence in the approved incident/recovery system.

## Verify recovery

- The normal protected plan and apply identities authenticate and operate at their intended scope.
- The external recovery grantor remains independently accessible and every configured
  impersonator still resolves to one named Cloud Identity user.
- The exact temporary conditional IAM binding is absent.
- Audit logs account for every impersonation and administrative action.
- Alerts were delivered and incident evidence names the operator, watcher, scope, and timestamps.
- Exposed recovery material is rotated and the permanent corrective action has an owner.

## Escalation and handoff

Hand the incident commander the incident ID, exact IAM condition, operators, action timeline,
audit-log query, alert evidence, affected resources, revocation proof, and remaining corrective
work. Escalate any action outside the declaration or any missing audit evidence to security.
