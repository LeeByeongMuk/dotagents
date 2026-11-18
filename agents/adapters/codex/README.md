# Codex 설정

[문서 목록](../../../docs/README.md) · [설치 안내](../../../docs/install.md)

공통 지침과 커밋 훅은 전역 설치기가 연결합니다. 모델, 권한, MCP와 앱이 관리하는 설정은 사용자의 `~/.codex/config.toml`에 남겨두며 설치기가 덮어쓰지 않습니다. 커밋 훅의 동작과 신뢰 절차는 [훅 안내](../../hooks/README.md)가 원본입니다.

## 설정 예제 적용

[config.example.toml](config.example.toml)은 모델, 추론 수준, 서비스 티어와 권한의 선택 예제입니다. 계정에서 사용할 수 있는 모델과 원하는 값만 기존 `~/.codex/config.toml`에 반영합니다. 파일 전체를 덮어쓰면 MCP와 앱 설정이 사라질 수 있으므로 필요한 키만 옮깁니다. 권한 예제는 `on-request`와 `workspace-write`이고, 기존 사용자의 `never`와 `danger-full-access` 같은 선택은 모델 설정과 별개로 유지합니다.

인증값, 프로젝트 경로, 앱이 생성한 로컬 런타임 설정은 예제에 넣지 않습니다. 설정 키의 지원 여부는 [공식 설정 참조](https://learn.chatgpt.com/docs/config-file/config-reference)를 확인합니다.

## 간단한 작업용 CLI 프로필

기본 설정을 유지하면서 추론 수준만 바꾸려면 [quick.config.example.toml](quick.config.example.toml)을 `~/.codex/quick.config.toml`로 복사하고 다음처럼 실행합니다. 같은 이름의 파일이 이미 있으면 기존 내용을 먼저 확인합니다.

```sh
codex --profile quick
```

이 프로필은 모델과 권한을 상속하고 추론 수준만 `medium`으로 바꿉니다. Codex CLI 0.134.0 이상은 별도 `<이름>.config.toml` 파일을 읽으며, 기존 `config.toml` 안의 `[profiles.quick]`와 `profile = "quick"` 선택자는 지원하지 않습니다. 사용자 지정 `CODEX_HOME`을 쓰면 그 디렉터리에 프로필 파일을 둡니다. [공식 프로필 안내](https://learn.chatgpt.com/docs/config-file/config-advanced#profiles)

## 설치 진단

`make doctor`는 dotagents의 기본 도구와 설치 상태를 읽기 전용으로 검사합니다. legacy에서는 Codex 커밋 훅 링크를, managed에서는 사용자 소유 `hooks.json`의 필수 훅 등록을 확인합니다. legacy 링크가 없으면 주 체크아웃에서 dry-run 후 재설치하고, managed 설정에 등록이 빠졌으면 doctor가 안내하는 예제를 수동 통합합니다. [레이아웃별 설정 계약](../../../docs/designs/install-layouts.md#사용자-설정과-hook-등록)

파일 검사가 통과해도 Codex의 실제 로딩·실행과 훅 신뢰 상태는 별도로 `/hooks`에서 확인합니다. dotagents의 `make doctor`와 Codex 자체 진단 명령은 별개입니다.

## 로컬 승인 규칙

CLI에서 저장한 명령 허용은 `~/.codex/rules/default.rules`에 쌓입니다. 종료된 작업의 고정 PID나 특정 커밋 메시지처럼 다시 쓰지 않을 항목은 백업 후 정리하고 Codex를 다시 시작합니다. 프로젝트 전용 허용 규칙은 신뢰한 프로젝트의 `.codex/rules/`에서 관리할 수 있습니다. [공식 명령 규칙 안내](https://learn.chatgpt.com/docs/agent-configuration/rules#create-a-rules-file)
