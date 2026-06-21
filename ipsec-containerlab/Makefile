.PHONY: build deploy verify destroy clean

build:
	docker build -t ipsec-alpine:latest .

deploy:
	./scripts/deploy.sh

verify:
	./scripts/verify.sh

destroy:
	./scripts/destroy.sh

clean: destroy
	docker image rm ipsec-alpine:latest 2>/dev/null || true
