.PHONY: validate validate-core validate-bazel-cache-identity validate-ci-config validate-drill-matrix validate-dr-readiness validate-iam-contract validate-plan-change validate-protected-run validate-production-contract validate-production-contract-tests validate-repository-home validate-terraform lint fmt fmt-check first-apply-workdir license-headers license-headers-fix

validate: validate-core validate-terraform validate-repository-home

validate-core: validate-bazel-cache-identity validate-ci-config validate-drill-matrix validate-dr-readiness validate-iam-contract validate-plan-change validate-protected-run validate-production-contract
	bash scripts/validate.sh

validate-bazel-cache-identity:
	python3 -m unittest tests.test_bazel_cache_identity

validate-ci-config:
	python3 -m unittest tests.test_ci_config

validate-drill-matrix:
	python3 scripts/validate-drill-matrix.py

validate-dr-readiness:
	python3 scripts/dr-readiness.py --check-doc >/dev/null
	python3 -m unittest tests.test_dr_readiness tests.test_prepare_drill tests.test_summarize_drift

validate-iam-contract:
	python3 -m unittest tests.test_iam_contract

validate-plan-change:
	python3 -m unittest tests.test_plan_change

validate-protected-run:
	python3 -m unittest tests.test_protected_run

validate-repository-home:
	python3 scripts/validate-repository-home.py --root .

validate-terraform: fmt-check
	@terraform_data_dir="$$(mktemp -d)" || exit 1; \
	trap 'rm -rf "$$terraform_data_dir"' EXIT; \
	TF_DATA_DIR="$$terraform_data_dir" terraform init -backend=false -input=false -lockfile=readonly; \
	TF_DATA_DIR="$$terraform_data_dir" terraform validate -no-color

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

validate-production-contract: validate-production-contract-tests
	python3 scripts/validate-production-contract.py

validate-production-contract-tests:
	python3 -m unittest tests.test_production_contract
