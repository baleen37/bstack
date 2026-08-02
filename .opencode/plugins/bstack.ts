const PLUGIN_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "")

const BLOCKS: Array<{ pattern: RegExp; message: string; info?: string }> = [
  {
    pattern: /git\s+commit.*--no-verify/,
    message: "--no-verify is not allowed in this repository",
    info: "Please use 'git commit' without --no-verify. All commits must pass quality checks.",
  },
  { pattern: /git\s+.*skip.*hooks/, message: "Skipping hooks is not allowed" },
  { pattern: /git\s+.*--no-.*hook/, message: "Hook bypass is not allowed" },
  { pattern: /HUSKY=0.*git/, message: "HUSKY=0 bypass is not allowed" },
  { pattern: /SKIP_HOOKS=.*git/, message: "SKIP_HOOKS bypass is not allowed" },
  { pattern: /git\s+update-ref/, message: "git update-ref is not allowed in this repository", info: "This command can bypass commit hooks." },
  { pattern: /git\s+filter-branch/, message: "git filter-branch is not allowed in this repository", info: "This command can rewrite history and bypass hooks." },
  { pattern: /git\s+config.*core\.hooksPath/, message: "Modifying core.hooksPath is not allowed in this repository", info: "This can disable commit hooks." },
]

const isGitCommand = (command: string): boolean => /^\s*(\S*=\S*\s+)*git\s+/.test(command)

export const Bstack = async () => {
  return {
    "tool.execute.before": async (
      input: { tool: string },
      output: { args?: { command?: string } },
    ) => {
      if (input.tool !== "bash") return
      const command = output.args?.command ?? ""
      if (!isGitCommand(command)) return

      for (const block of BLOCKS) {
        if (block.pattern.test(command)) {
          throw new Error(block.info ? `${block.message}\n${block.info}` : block.message)
        }
      }

      if (/git\s+commit/.test(command) && /Co-Authored-By:/.test(command)) {
        throw new Error("Co-Authored-By trailers are not allowed in commit messages\nPlease remove 'Co-Authored-By:' from your commit message.")
      }
    },
    "shell.env": async (_input: unknown, output: { env: Record<string, string> }) => {
      if (!output.env.CLAUDE_PLUGIN_ROOT) {
        output.env.CLAUDE_PLUGIN_ROOT = PLUGIN_ROOT
      }
    },
  }
}
