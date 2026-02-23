# GitHub App Setup Guide

이 가이드는 semantic-release에서 생성한 PR이 CI workflow를 trigger하도록 GitHub App을 설정하는 방법을 안내합니다.

## Problem

`GITHUB_TOKEN`으로 생성한 PR은 다른 workflow를 trigger하지 않는 GitHub의 보안 정책이 있습니다. 이를 해결하기 위해 GitHub App을 사용합니다.

## Solution Overview

1. GitHub App 생성 및 설치
2. Repository Secret 설정
3. Workflow에서 GitHub App token 사용

---

## Step 1: GitHub App 생성

### 1.1 GitHub App 등록

1. GitHub에서 **Settings** -> **Developer settings** -> **GitHub Apps**로 이동
2. **New GitHub App** 클릭

### 1.2 App 설정

다음 정보를 입력합니다:

| 필드 | 값 |
| ---- | --- |
| **GitHub App name** | `claude-plugins-ci` (또는 원하는 이름) |
| **Homepage URL** | `https://github.com/[your-username]/claude-plugins` |
| **Description** | `CI automation for claude-plugins` |

### 1.3 권한 설정 (Permissions)

**Repository permissions**:

| Permission | Access |
| ---------- | ------ |
| Contents | **Read and write** |
| Pull requests | **Read and write** |
| Workflows | **Read and write** (중요!) |

### 1.4 이벤트 설정 (Events)

다음 이벤트를 체크:

- [x] Push
- [x] Pull request
- [x] Workflow run

### 1.5 App 생성

1. **Create GitHub App** 클릭
2. 생성 후 **App ID**와 **Webhook secret** (있는 경우)을 기록
3. **Generate a new client secret** 클릭하여 **Client secret** 기록
4. **Generate a new private key** 클릭하여 `.pem` 파일 다운로드

**중요**: 생성된 정보를 안전하게 보관하세요:

- App ID
- Client ID (App 페이지 상단에 표시)
- Client secret
- Private key (.pem 파일)

---

## Step 2: GitHub App 설치

### 2.1 Repository에 설치

1. GitHub App 페이지에서 **Install App** 또는 **Install on your account** 클릭
2. **claude-plugins** repository 선택
3. **Install** 클릭

---

## Step 3: GitHub Secrets 설정

### 3.1 App ID 설정

1. Repository에서 **Settings** -> **Secrets and variables** -> **Actions**로 이동
2. **New repository secret** 클릭
3. Name: `GH_APP_ID`
4. Value: [App ID] (숫자만 입력)

### 3.2 App Private Key 설정

1. **New repository secret** 클릭
2. Name: `GH_APP_PRIVATE_KEY`
3. Value: `.pem` 파일의 전체 내용을 붙여넣기

```text
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(전체 내용)
...
-----END RSA PRIVATE KEY-----
```

### 3.3 (선택사항) Client Secret 설정

Webhook을 사용하는 경우에만 필요합니다:

1. **New repository secret** 클릭
2. Name: `GH_APP_CLIENT_SECRET`
3. Value: [Client secret]

---

## Step 4: Workflow 수정

### 4.1 Token 생성 Action 추가

`release.yml`에 GitHub App token을 생성하는 단계를 추가합니다:

```yaml
- name: Generate GitHub App Token
  id: generate-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.GH_APP_ID }}
    private-key: ${{ secrets.GH_APP_PRIVATE_KEY }}
```

### 4.2 GITHUB_TOKEN 대신 사용

```yaml
- name: Release
  env:
    GITHUB_TOKEN: ${{ steps.generate-token.outputs.token }}
    ...
```

---

## Verification

### 테스트 방법

1. main 브랜치에 Conventional Commit 형식으로 커밋:

   ```bash
   git commit -m "feat: test GitHub App trigger"
   git push origin main
   ```

2. Release workflow가 완료되면 PR이 생성됩니다

3. 생성된 PR에서 **Checks** 탭을 확인:
   - Plugin Tests workflow가 실행되어야 합니다

---

## Troubleshooting

### 문제: Tests workflow가 실행되지 않음

**확인사항**:

1. GitHub App의 **Workflow runs** 권한이 **Read and write**인지 확인
2. App이 repository에 설치되어 있는지 확인
3. Secrets가 올바르게 설정되어 있는지 확인

### 문제: Permission denied 오류

**해결방법**:

1. GitHub App의 permissions을 다시 확인
2. App을 재설치 (permissions 변경 후 필요)

### 문제: Invalid credentials 오류

**해결방법**:

1. Private key가 올바르게 복사되었는지 확인 (전체 내용)
2. App ID가 올바른지 확인

---

## Alternative: workflow_run 방식

GitHub App 설정이 복잡한 경우, `workflow_run` 트리거를 사용하는 방식도 있습니다. 이미 `.github/workflows/test.yml`에 구현되어 있습니다.

**장점**:

- 추가 설정 없음
- 간단하고 직관적

**단점**:

- PR 생성 후 즉시 test가 실행되지 않음
- Release workflow 완료 후 실행됨

---

## 참고 자료

- [GitHub Apps Documentation](https://docs.github.com/en/developers/apps)
- [Creating a GitHub App](https://docs.github.com/en/developers/apps/creating-a-github-app)
- [Authenticating with GitHub Apps](https://docs.github.com/en/developers/apps/authenticating-with-github-apps)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
