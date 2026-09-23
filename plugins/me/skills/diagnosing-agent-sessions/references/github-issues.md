# GitHub issues

Use GitHub only when the issue destination is known. A session's active
project repository is not automatically the repository for a `me` or harness
bug.

## Resolve the destination

Use, in order:

1. The exact `owner/repo` the human named for this report.
2. A GitHub remote from a checkout verified to be the `me` source repository.
3. The project's configured issue tracker only when the report concerns that
   project's own behavior, not a `me` or harness bug.

Never guess from the author's name, plugin display name, or another project's
remote. If no destination is verified, ask the human which repository to use
and stop before searching or creating anything. Set `REPO=owner/repo` only
after resolving it.

## Search

Search both states and restrict results to issues. Check the duplicate-search
box in the issue template only after both searches are complete:

```bash
gh search issues --repo "$REPO" --state open --limit 10 "is:issue <terms>"
gh search issues --repo "$REPO" --state closed --limit 10 "is:issue <terms>"
```

If `gh` is unavailable, use the public API only for a public GitHub repo:

```bash
curl -s -H "Accept: application/vnd.github+json" \
  "https://api.github.com/search/issues?q=repo:<owner>/<repo>+is:issue+<url-encoded-terms>&per_page=10"
```

If neither route is available, give the human a search link for the verified
repository. Do not include transcript contents in search terms.

## File an issue

Write the filled `templates/issue.md` to the diagnosis workspace and show the
exact text. Create it only after the human approves that exact text:

```bash
gh issue create --repo "$REPO" --title "<title>" --body-file <path>
```

Do not assume labels exist or apply them without checking. `gh` cannot attach
files; if an approved bundle exists, give the human its path to attach in the
browser. Never upload a transcript or archive yourself.
