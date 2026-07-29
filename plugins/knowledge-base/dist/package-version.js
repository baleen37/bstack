import { readFileSync } from "node:fs";
export function readPackageVersion(file = new URL("../package.json", import.meta.url)) {
    let packageJson;
    try {
        packageJson = JSON.parse(readFileSync(file, "utf8"));
    }
    catch (cause) {
        throw new Error("package version is unavailable", { cause });
    }
    if (typeof packageJson.version !== "string" || packageJson.version === "") {
        throw new Error("package version is unavailable");
    }
    return packageJson.version;
}
export const PACKAGE_VERSION = readPackageVersion();
//# sourceMappingURL=package-version.js.map