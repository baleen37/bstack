import { describe, expect, it } from "vitest";
import { isScope } from "../src/types.js";

describe("isScope", () => {
  it.each(["personal", "wooto", "all"])(`accepts %s`, (scope) => {
    expect(isScope(scope)).toBe(true);
  });

  it.each(["", "shared", "organization", "ALL"])(`rejects %s`, (scope) => {
    expect(isScope(scope)).toBe(false);
  });
});
