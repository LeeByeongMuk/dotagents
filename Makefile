# Common entry points. Run `make help` to list them.

.DEFAULT_GOAL := help
BREW ?= brew

.PHONY: help deps doctor build check test install install-dry uninstall

help: ## 타깃 목록
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  %-14s %s\n", $$1, $$2 }'

deps: ## 필수 도구 설치 (macOS Homebrew)
	$(BREW) install git jq ripgrep gh

doctor: ## 필수 도구와 전역 Codex 커밋 훅 링크 진단
	./tooling/scripts/doctor.sh

build: ## 어댑터와 공통 규칙을 합쳐 dist 최종본 생성
	./tooling/scripts/build.sh

check: ## 저장소 전체 검사
	./tooling/scripts/check.sh

test: ## 모든 회귀 테스트
	@for t in tooling/tests/*_test.sh; do echo "== $$t"; "$$t" >/dev/null || exit 1; done; echo "all tests passed"

install-dry: ## 전역 설치 dry-run
	./tooling/scripts/install.sh --dry-run --global

install: ## 전역 설치
	./tooling/scripts/install.sh --global

uninstall: ## 전역 제거
	./tooling/scripts/uninstall.sh --global
