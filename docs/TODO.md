# 유지보수 TODO

## 스킬 실행 지침 영문화

- [ ] [FSD 리팩터링 스킬](../agents/skills/owned/fsd-refactor/SKILL.md)의 설명과 실행 절차를 영어로 옮기고, “FSD 위반 검토”, “구조 리팩터링” 같은 한국어 요청 표현을 설명에 남긴다. 같은 모델과 한국어 요청으로 변경 전후의 입력 토큰 수와 동작을 비교한다. 검토 요청에서는 파일과 Git 상태가 그대로인지, 수정 요청에서는 파일을 옮겨도 기존 미커밋 변경과 스테이징 상태가 보존되는지 확인한다.
- [ ] FSD 스킬 비교 결과를 보고 [저장소 활동 정리 스킬](../agents/skills/owned/repo-activity-review/SKILL.md)의 Git·GitHub 수집 절차를 영어로 옮길지 결정한다. 바꾼다면 같은 활동 기록으로 기간 경계, PR·커밋 중복 집계, 페이지 누락 표시를 대조한다. “주간 회고”, “기여 내역” 같은 요청 표현과 한국어 기본 보고는 유지한다.

## 커밋 메시지 평가

- [ ] [평가 실행기](../tooling/evals/commit-message/run.sh)의 통과 판정에 [사례별 기대 언어](../tooling/evals/commit-message/cases.json)의 `expect.language`를 반영한다. 한국어·영어 로그 각각에서 형식은 맞지만 설명 언어가 다른 메시지가 실패하는지 확인한다. [이전에 관찰한 언어 오류](evals/commit-message-rule-compression.md#결과)
