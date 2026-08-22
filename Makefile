.PHONY: validate validate-drill-matrix validate-repository-home lint fmt fmt-check first-apply-workdir license-headers license-headers-fix

validate: validate-drill-matrix validate-production-contract validate-repository-home
	bash scripts/validate.sh

validate-drill-matrix:
	python3 scripts/validate-drill-matrix.py

validate-repository-home:
	python3 scripts/validate-repository-home.py --root .

lint:
	actionlint -config-file .github/actionlint.yaml .github/workflows/*.yml
	yamllint -c .yamllint.yaml .
	shellcheck scripts/*.sh

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive -diff

first-apply-workdir:
	@test -n "$(SOURCE_SHA)" || { echo "SOURCE_SHA must be the reviewed full commit SHA" >&2; exit 2; }
	@test -n "$(FIRST_APPLY_WORK_DIR)" || { echo "FIRST_APPLY_WORK_DIR must be a new path on approved encrypted storage" >&2; exit 2; }
	@python3 scripts/prepare-first-apply.py \
		--commit "$(SOURCE_SHA)" \
		--work-dir "$(FIRST_APPLY_WORK_DIR)"

license-headers:
	python3 scripts/license-header-check.py --check

license-headers-fix:
	python3 scripts/license-header-check.py --fix

.PHONY: validate-production-contract
validate-production-contract:
	python3 scripts/validate-production-contract.py
