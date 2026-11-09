REPO_ROOT := $(shell pwd)
WORK_DIR  := $(REPO_ROOT)/.build
OUT       := $(REPO_ROOT)/dist
PIN       := $(shell cat $(REPO_ROOT)/PIN 2>/dev/null || echo '')

.PHONY: all build tarball appimage srpm clean repin check-pin toolchain

all: build tarball appimage srpm

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

srpm:
	./scripts/build-srpm.sh

clean:
	rm -rf $(WORK_DIR) $(OUT)

repin: check-pin
	@echo "==> repin to $(PIN)"
	@echo "$(PIN)" > PIN
	rm -rf $(WORK_DIR)
	@echo "==> checking patch drift"
	./scripts/check-drift.sh || { \
	  echo "resolve conflicts, regenerate .patch files, then re-run" >&2; \
	  exit 1; \
	}
	@echo "==> building with reconciled patches"
	./scripts/build-linux.sh --pin $(PIN)
	@echo "==> build succeeded; update baseline"
	@echo "$(PIN)" > PIN_BASELINE
	@echo "==> review: git diff source-patches/ PIN_BASELINE"
