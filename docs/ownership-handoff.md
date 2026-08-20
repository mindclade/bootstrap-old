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
