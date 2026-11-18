# 직접 만든 스킬

[문서 목록](../../../docs/README.md) · [스킬 추가·제거](../README.md) · [외부 스킬 관리](../../../docs/external-skills.md)

지원 호스트에서 `$스킬명`을 지정하거나 해당 작업을 요청합니다. 각 스킬의 실행 조건과 결과 계약은 연결된 `SKILL.md`가 원본입니다.

| 스킬 | 하는 일 | 요청 예시 |
| --- | --- | --- |
| [product-development-workflow](product-development-workflow/SKILL.md) | 기획은 Plan, 구현은 Brief → Execute → Verify. 기존 PRD·이슈를 재사용 | “이 PRD대로 구현하고 검증해줘” |
| [fsd-refactor](fsd-refactor/SKILL.md) | FSD를 이미 쓰는 프로젝트에서 동작·렌더 결과·URL·API를 보존하며 구조 정리 | “이 슬라이스의 FSD 위반을 검토해줘” |
| [dotagents-promote](dotagents-promote/SKILL.md) | 재사용할 관례를 별도 worktree 브랜치에 반영하고 커밋. main 병합은 별도 결정 | “이번에 정한 공통 규칙을 dotagents에 반영해줘” |
| [usage-guide](usage-guide/SKILL.md) | 화면·번호 설명·FAQ를 갖춘 최종 사용자용 16:9 PDF와 단일 HTML 제작 | “방금 만든 기능의 사용 가이드를 만들어줘” |
| [repo-activity-review](repo-activity-review/SKILL.md) | 저장소의 실제 변경·검증 근거로 기간별 개발 활동을 대화에 정리 | “이 저장소의 지난주 개발 활동을 정리해줘” |

작은 수정·단일 버그·설명에는 제품 개발 워크플로우를 강제하지 않습니다. 제품 기획만 요청하면 파일이나 구현을 바꾸지 않는 Plan에서 끝납니다. [제품 개발 사용 안내](../../workflows/product-development/WORKFLOW.md)

전역·프로젝트 링크 설치는 이 디렉터리의 모든 유효한 스킬을 대상으로 합니다. 일부 스킬 선택 설치와 프로필 필터는 제공하지 않습니다. 전역과 프로젝트에 같은 이름의 스킬이 있으면 호스트가 우선순위를 결정하므로 프로젝트 전용 스킬에는 다른 이름을 사용합니다.
