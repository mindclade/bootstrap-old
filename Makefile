.PHONY: validate lint fmt fmt-check plan-local license-headers license-headers-fix

validate: validate-production-contract
	bash scripts/validate.sh

lint:
	actionlint -config-file .github/actionlint.yaml .github/workflows/*.yml
	yamllint -c .yamllint.yaml .
	shellcheck scripts/*.sh

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive -diff

plan-local:
	terraform init -backend=false
	terraform plan -lock-timeout=20m

license-headers:
	bash scripts/license-header-check.sh --check

license-headers-fix:
	bash scripts/license-header-check.sh --fix

.PHONY: validate-production-contract
validate-production-contract:
	python3 scripts/validate-production-contract.py
