# Bootstrap contracts

The output contract is the only supported machine interface from Ring 0. It exports non-secret state, federation, and automation-identity identifiers. Consuming repositories must not read bootstrap implementation details or Terraform state directly.
