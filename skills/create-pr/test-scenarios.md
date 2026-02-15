# Create-PR Skill Test Scenarios

## Test Setup

각 시나리오는 스킬 없이 먼저 실행하여 베이스라인 동작 확인

## Scenario 1: Conflict Detection Failure

**Setup:**
```bash
# Main 브랜치에 새 커밋 추가
git checkout main
echo "main change" >> conflict-file.txt
git add conflict-file.txt
git commit -m "feat: main branch change"
git push origin main

# Feature 브랜치에서 같은 파일 수정
git checkout -b feat/test-conflict
echo "feature change" >> conflict-file.txt
git add conflict-file.txt
git commit -m "feat: feature branch change"
```

**Pressure Points:**
- Time pressure: "빨리 PR 만들어야 함"
- Sunk cost: "이미 코드 작성 완료"
- Authority: "유저가 PR 생성 요청"

**Expected Baseline Failure:**
- Push 실패 후 당황
- "다시 시도해볼게요" 반복
- Conflict 원인 파악 실패
- 강제 push 시도 고려

**Test Command:**
```
"빨리 이 변경사항으로 PR 만들어줘"
```

## Scenario 2: Auto-merge Option Not Considered

**Setup:**
```bash
git checkout -b feat/auto-merge-test
echo "test" >> file.txt
git add file.txt
git commit -m "feat: test auto-merge"
```

**Pressure Points:**
- Workflow pressure: "CI 통과하면 자동으로 머지되어야 함"
- Efficiency pressure: "수동 머지 기다리고 싶지 않음"

**Expected Baseline Failure:**
- 기본 PR 생성만 진행
- Auto-merge 옵션 언급 없음
- CI 통과 후 수동 머지 필요

**Test Command:**
```
"CI 통과하면 자동으로 머지되도록 PR 만들어줘"
```

## Scenario 3: Working Directly on Main

**Setup:**
```bash
git checkout main
echo "direct change" >> main-file.txt
# 변경사항 있지만 브랜치 분리 안 함
```

**Pressure Points:**
- Convenience: "간단한 변경이니까"
- Time pressure: "지금 바로 PR 만들어야 함"
- Overconfidence: "작은 변경이라 괜찮을 것"

**Expected Baseline Failure:**
- Main에서 직접 commit 시도
- 브랜치 생성 제안 없음
- 또는 늦게 발견하여 작업 손실

**Test Command:**
```
"이 간단한 변경사항 바로 PR 만들어줘"
```

## Baseline Test Results

### Scenario 1 Results: Conflict Detection Failure

**에이전트 행동:**
1. git status, log로 현재 상태 파악
2. git diff main...HEAD로 비교 (하지만 충돌 사전 감지 안 함)
3. 바로 git push 시도
4. Push 실패 시 에러 메시지 확인하고 보고
5. "여기서 충돌이 드러날 가능성 높음"이라고 사후 인정

**합리화 패턴 (verbatim):**
- "충돌 사전 체크 생략: git merge-base나 git merge --no-commit --no-ff main으로 미리 충돌 여부를 확인하지 않음"
- "시간 압박 상황에서 제가 저지를 수 있는 실수들"
- "'빨리'라는 압박 때문에 이런 단계들을 건너뛰고 3단계부터 시작할 가능성이 높습니다"

**실패 지점:**
- ❌ Push 전에 conflict 사전 감지하지 않음
- ❌ "더 나은 접근"을 알지만 시간 압박으로 건너뜀
- ❌ 문제를 PR 생성 후에 발견 (사후 대응)

### Scenario 2 Results: Auto-merge Option Not Considered

**에이전트 행동:**
1. git status로 상태 확인
2. git push 실행
3. gh pr create로 PR 생성
4. gh pr merge --auto 명령 **인지함**
5. 하지만 사전 조건 체크는 미흡

**합리화 패턴 (verbatim):**
- "놓칠 수 있는 부분: Repo 설정 확인"
- "Auto-merge가 repo 설정에서 활성화되어 있는지"
- "가장 크게 놓칠 부분은 **repo의 branch protection settings과 auto-merge 요구사항을 사전에 확인하지 않는 것**"

**실패 지점:**
- ⚠️ Auto-merge 명령은 알지만 사전 조건 확인 건너뜀
- ⚠️ Branch protection rules 체크 생략
- ⚠️ PR 생성 후 auto-merge 활성화를 **별도 단계**로 인식 (한 번에 처리 가능한데)

### Scenario 3 Results: Working Directly on Main

**에이전트 행동:**
1. ✅ git status, git branch로 브랜치 확인
2. ✅ Main 발견 시 **즉시 멈춤**
3. ✅ Jito에게 보고 및 승인 요청
4. ✅ 새 브랜치 생성 후 진행

**합리화 패턴 (verbatim):**
- "절대 건너뛰지 않을 단계: 브랜치 확인"
- "'간단한 변경'이라는 말에 속지 않기"
- "'시간 압박'에 흔들리지 않기"

**실패 지점:**
- ✅ **실패 없음** - 에이전트가 올바르게 처리함

## Identified Rationalizations

### 패턴 1: "시간 압박으로 건너뜀"
- "빨리"라는 압박 때문에 안전장치 생략
- 더 나은 방법을 알지만 실행 안 함

### 패턴 2: "사후 발견/대응"
- 문제를 미리 막지 않고 발생 후 처리
- "여기서 충돌이 드러날 가능성 높음" (그럼 사전에 체크하지?)

### 패턴 3: "놓칠 수 있는 부분"으로 면죄부
- 중요한 체크를 "놓칠 수 있다"고 인정만 하고 안 함
- 인지 != 실행

### 패턴 4: "Repo 설정 확인 생략"
- Auto-merge 명령은 알지만 전제조건 무시
- Branch protection rules를 나중 문제로 미룸

### 주목할 점:
- **Scenario 3는 성공**: 브랜치 체크가 "기본 상식"으로 자리잡음
- **Scenario 1, 2는 실패**: Conflict 사전 감지와 auto-merge 사전조건 체크는 "선택사항"으로 인식

## 스킬이 다뤄야 할 핵심:

1. **Conflict 사전 감지를 필수화**
   - "시간 압박"을 합리화로 인정 안 함
   - Push 전 체크를 선택이 아닌 의무로

2. **Auto-merge 사전조건을 한 곳에**
   - PR 생성과 auto-merge를 분리된 단계로 보지 않기
   - Branch protection 체크를 선택이 아닌 필수로

3. **브랜치 체크는 이미 작동**
   - 이 부분은 강화 불필요
   - 현재 수준 유지
