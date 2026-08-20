# Ownership handoff

The following legacy bootstrap authorities are removed from this repository and must be
imported into the matching `infrastructure-live/1-org` Terragrunt state before either side is
applied destructively:

- normal folder hierarchy;
- organization policies;
- Essential Contacts;
- billing governance/export;
- normal organization log sinks and audit destinations.

Use `terraform state rm` only after the destination import and a no-op plan are proven. Never
allow both repositories to manage the same resource simultaneously.

## Ring-0 internal ownership cleanup

`monitoring.googleapis.com` is owned only by
`module.projects.google_project_service.seed["monitoring.googleapis.com"]`. Older bootstrap
state can also contain `module.identity.google_project_service.monitoring` for the same API.
The root `removed` block forgets that duplicate address with `destroy = false`. Confirm the
plan reports a state-only removal and that Monitoring remains enabled; do not replace this
transition with a destructive state or API operation.
