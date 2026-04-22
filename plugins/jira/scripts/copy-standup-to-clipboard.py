#!/usr/bin/env python3
"""
Read a standup report from stdin and copy to macOS clipboard as rich text
(HTML + plain text) so Slack renders Jira issue keys as hyperlinks on paste.

Input format (stdin): the standup report exactly as printed by the skill,
with lines like `  - SEARCH-12134 summary ...`. Issue keys matching
`[A-Z]+-\\d+` are converted to hyperlinks pointing at
https://croquis.atlassian.net/browse/<KEY>.

Usage:
    pbpaste | copy-standup-to-clipboard.py      # from clipboard
    copy-standup-to-clipboard.py < report.txt   # from file
"""

import html
import re
import subprocess
import sys

JIRA_BASE = "https://croquis.atlassian.net/browse"
ISSUE_RE = re.compile(r"\b([A-Z][A-Z0-9]+-\d+)\b")


def to_html(text: str) -> str:
    escaped_lines = []
    for raw in text.splitlines():
        stripped = raw.lstrip(" ")
        indent = len(raw) - len(stripped)
        pad = "&nbsp;" * indent
        if stripped.startswith("- "):
            body = html.escape(stripped[2:])
            body = ISSUE_RE.sub(
                lambda m: f'<a href="{JIRA_BASE}/{m.group(1)}">{m.group(1)}</a>',
                body,
            )
            escaped_lines.append(f"{pad}• {body}")
        else:
            escaped_lines.append(pad + html.escape(stripped))
    return "<br>\n".join(escaped_lines)


def set_clipboard(html_str: str, plain_str: str) -> None:
    script = f"""
use framework "AppKit"
use scripting additions

set pb to current application's NSPasteboard's generalPasteboard()
pb's clearContents()
set htmlStr to current application's NSString's stringWithString:{_as_applescript_string(html_str)}
set plainStr to current application's NSString's stringWithString:{_as_applescript_string(plain_str)}
pb's setString:htmlStr forType:"public.html"
pb's setString:plainStr forType:"public.utf8-plain-text"
"""
    result = subprocess.run(
        ["osascript", "-l", "AppleScript", "-e", script],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        sys.exit(result.returncode)


def _as_applescript_string(s: str) -> str:
    escaped = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'


def main() -> None:
    plain = sys.stdin.read()
    if not plain.strip():
        sys.stderr.write("No input on stdin.\n")
        sys.exit(1)
    set_clipboard(to_html(plain), plain)
    print("Copied standup to clipboard (HTML + plain). Paste into Slack.")


if __name__ == "__main__":
    main()
