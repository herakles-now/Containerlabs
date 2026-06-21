.PHONY: build bridges deploy configure verify test capture state destroy clean

CASE ?= all

build:
	docker build -t nat4-lab:latest .

bridges:
	./scripts/setup-host-bridges.sh

deploy: build bridges
	containerlab deploy --topo clab.yml
	./scripts/configure-all.sh

configure:
	./scripts/configure-all.sh

verify:
	./scripts/test-all.sh

test:
	@case "$(CASE)" in \
		static) ./scripts/test-static-nat.sh ;; \
		dynamic) ./scripts/test-dynamic-nat.sh ;; \
		forward) ./scripts/test-port-forward.sh ;; \
		pat) ./scripts/test-pat.sh ;; \
		all) ./scripts/test-all.sh ;; \
		*) echo "ERROR: CASE must be static, dynamic, forward, pat, or all." >&2; exit 2 ;; \
	esac

capture:
	@case "$(CASE)" in \
		static) ./scripts/capture-static-nat.sh ;; \
		dynamic) ./scripts/capture-dynamic-nat.sh ;; \
		forward) ./scripts/capture-port-forward.sh ;; \
		pat) ./scripts/capture-pat.sh ;; \
		*) echo "ERROR: CASE must be static, dynamic, forward, or pat." >&2; exit 2 ;; \
	esac

state:
	./scripts/show-state.sh

destroy:
	@if containerlab inspect --topo clab.yml >/dev/null 2>&1; then containerlab destroy --topo clab.yml --cleanup; fi
	./scripts/cleanup-host-bridges.sh

clean: destroy
	docker image rm nat4-lab:latest 2>/dev/null || true
