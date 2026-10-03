# GitHub issues

Use `gh` when it is installed and authenticated; it handles auth, rate
limits, and JSON. Fall back to the public API with curl, then to a URL
your partner opens.

## Search

```bash
gh search issues --repo baleen37/skills --limit 10 "<terms>" \
  --json number,state,title --jq '.[] | "\(.number)\t\(.state)\t\(.title)"'
```

Without `gh` (unauthenticated, 10 requests a minute):

```bash
curl -s -H "Accept: application/vnd.github+json" \
  "https://api.github.com/search/issues?q=repo:baleen37/skills+is:issue+<url-encoded terms>&per_page=10" \
  | jq -r '.items[] | "\(.number)\t\(.state)\t\(.title)"'
```

Without curl, hand over `https://github.com/baleen37/skills/issues?q=<terms>`.

## File

Write the filled `templates/issue.md` to the workspace and show the exact
text. After approval:

```bash
gh issue create --repo baleen37/skills --title "<title>" --body-file <path>
```

Use existing repository labels when appropriate; the template footer marks
the issue as skill-filed. `gh` cannot attach files: give your partner the
bundle path to attach through the browser after the issue exists.

Without `gh`, hand over a prefilled issue link:

```
https://github.com/baleen37/skills/issues/new?title=<url-encoded title>&body=<url-encoded body>
```

GitHub rejects URLs over about 8,000 characters; past that, send the link
with the title only and tell your partner to paste the body from the file.
