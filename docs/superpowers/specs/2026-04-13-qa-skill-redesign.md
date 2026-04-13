# QA Skill Redesign Spec

## Goal

`/qa` 스킬을 범용적으로 개선. 프로젝트 타입에 독립적이고, 토큰 효율적인 탐색+리포트 전용 스킬.

## Decisions

| Decision | Choice |
|----------|--------|
| Scope | 탐색 + 리포트 전용. Fix는 별도 스킬에 위임 |
| Browser | QA에서 제거. 웹 테스트 시 `/browse` 별도 사용 |
| QA strategy | 프로젝트 타입별 고정 체크리스트 없음. Analyze 단계에서 동적 수립 |
| Test framework | 없으면 안내만. 부트스트랩 안 함 |
| Report structure | `.qa/reports/` 유지 (MD + baseline.json + evidence/) |
| Location | `plugins/me/skills/qa/` 유지 |
| Parameters | 없음. 자연어로 scope 지정 |
| Fix transition | 리포트 후 사용자에게 수정 여부 질문. A) subagent-driven B) inline(executing-plans) C) 종료 |

## Flow

1. **Analyze** — 프로젝트 파악 (README, 구조, 엔트리포인트, 테스트 유무, 빌드 시스템) → QA 전략 수립
2. **Explore + Report** — 전략대로 테스트, 이슈 발견 즉시 기록 + evidence 저장, 리포트 생성
3. **Transition** — "N개 이슈를 발견했습니다. 수정하시겠습니까?"
   - A) Subagent-driven → `superpowers:subagent-driven-development` 호출
   - B) Inline → `superpowers:executing-plans` 호출
   - C) 아니오 → 종료

## File Structure

```
plugins/me/skills/qa/
├── SKILL.md                        # 핵심 플로우만 (~80줄)
├── references/
│   ├── issue-taxonomy.md           # 심각도/카테고리 정의 (기존 유지)
│   └── exploration-guide.md        # 프로젝트 타입별 참고 (필요 시 Read)
└── templates/
    └── qa-report-template.md       # Fix/Regression 섹션 제거
```

## SKILL.md Content (Always Loaded)

- 3단계 플로우
- 핵심 규칙 (evidence 필수, 재현성 확인, 즉시 기록)
- Health score 계산식
- Transition 선택지

## References (Read on Demand)

- `issue-taxonomy.md` — 심각도/카테고리 정의. exploration 체크리스트는 "참고자료"로 격하
- `exploration-guide.md` — 기존 issue-taxonomy.md의 "Exploration Checklists" 섹션 + SKILL.md의 프로젝트 타입별 섹션을 합쳐서 추출한 새 파일

## Removed from Current Skill

- Browser tool section (`mcp__plugin_superpowers-chrome_chrome__use_browser`)
- Test framework bootstrap
- Fix Loop (Phase 3), Final QA (Phase 4)
- WTF-likelihood, self-regulation
- Project type-specific fixed checklists (moved to references)
- Tier/Mode/Parameter tables
- Clean working tree enforcement
- Regression mode

## Token Budget

- Current: ~390 lines
- Target: ~80 lines for SKILL.md
- Heavy content → references/ (loaded on demand)
