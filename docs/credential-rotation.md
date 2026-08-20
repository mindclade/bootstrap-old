# Credential and trust rotation

Normal automation is keyless. Rotate trust by changing WIF providers, repository IDs,
service-account bindings, and protected-environment policy—not by distributing JSON keys.

After a GitHub repository transfer or recreation:

1. obtain its new immutable repository ID;
2. update `github_repository_ids`;
3. apply bootstrap through the protected environment;
4. run WIF preflight from the repository;
5. revoke the old provider/binding;
6. review token-exchange audit logs.

After break-glass use, remove temporary IAM grants, review audit logs, rotate any exposed
recovery material, and record a post-incident review.
