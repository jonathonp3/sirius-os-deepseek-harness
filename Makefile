REPO_ROOT := $(shell pwd)
WORK_DIR  := $(REPO_ROOT)/.build
OUT       := $(REPO_ROOT)/dist
PIN       := $(shell cat $(REPO_ROOT)/PIN 2>/dev/null || echo '')

.PHONY: all build tarball appimage rpm clean repin check-pin

all: build tarball appimage rpm

toolchain:
	./scripts/toolchain.sh

check-pin:
	@test -n "$(PIN)" || { echo "error: PIN is empty"; exit 1; }

build: check-pin
	./scripts/build-linux.sh

tarball:
	./scripts/make-tarball.sh

appimage:
	./scripts/make-appimage.sh

rpm:
	./scripts/make-rpm.sh

clean:
	rm -rf $(WORK_DIR) $(OUT)

repin: check-pin
	@echo "==> repin to $(PIN)"
	@echo "$(PIN)" > PIN
	rm -rf $(WORK_DIR)
	./scripts/build-linux.sh --pin $(PIN)
	@echo "==> build succeeded; refreshing source-patches"
	@for f in $$(cd source-patches && find apps -type f); do \
	  cp "$(WORK_DIR)/deepseek-harness/$$f" "source-patches/$$f"; \
	done
	@echo "==> review with: git diff source-patches/"

