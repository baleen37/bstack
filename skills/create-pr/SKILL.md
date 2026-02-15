---
name: create-pr
description: Create PR - commit, push, open pull request
---

# Workflow

```bash
# Read template
cat .github/{pull_request_template,PULL_REQUEST_TEMPLATE}.md \
    .github/PULL_REQUEST_TEMPLATE/*.md PULL_REQUEST_TEMPLATE.md 2>/dev/null | head -1

# Status
git status && git log --oneline -5

# Commit
git add <files> && git commit -m "type(scope): msg"

# Push & PR
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "..."
```

# Stop: main/master, no changes, not approved
