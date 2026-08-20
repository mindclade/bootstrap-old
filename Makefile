.PHONY: validate fmt plan-local license-headers license-headers-fix

validate: validate-production-contract
	bash scripts/validate.sh

fmt:
	terraform fmt -recursive

plan-local:
	terraform init -backend=false
	terraform plan -lock=false

license-headers:
	bash scripts/license-header-check.sh --check

license-headers-fix:
	bash scripts/license-header-check.sh --fix

.PHONY: validate-production-contract
validate-production-contract:
	python3 scripts/validate-production-contract.py
