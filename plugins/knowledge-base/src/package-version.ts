import { readFileSync } from "node:fs";

export function readPackageVersion(
  file: string | URL = new URL("../package.json", import.meta.url),
): string {
  let packageJson: { version?: unknown };
  try {
    packageJson = JSON.parse(readFileSync(file, "utf8")) as { version?: unknown };
  } catch (cause) {
    throw new Error("package version is unavailable", { cause });
  }
  if (typeof packageJson.version !== "string" || packageJson.version === "") {
    throw new Error("package version is unavailable");
  }
  return packageJson.version;
}

export const PACKAGE_VERSION = readPackageVersion();
