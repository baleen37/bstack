export const SCOPES = ["personal", "wooto", "all"];
export function isRepository(value) {
    const match = /^([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)$/.exec(value);
    if (match === null) {
        return false;
    }
    const [, owner, name] = match;
    return owner !== "." && owner !== ".." && name !== "." && name !== "..";
}
export function isScope(value) {
    return SCOPES.includes(value);
}
//# sourceMappingURL=types.js.map