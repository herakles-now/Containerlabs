.PHONY: build deploy verify destroy clean

build:
	docker build -t ipsec-lab:latest .

deploy:
	./scripts/deploy.sh

verify:
	./scripts/verify.sh

destroy:
	./scripts/destroy.sh

clean: destroy
	docker image rm ipsec-lab:latest 2>/dev/null || true
