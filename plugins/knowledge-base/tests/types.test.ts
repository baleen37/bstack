import { describe, expect, it } from "vitest";
import { isRepository, isScope } from "../src/types.js";

describe("isScope", () => {
  it.each(["personal", "wooto", "all"])(`accepts %s`, (scope) => {
    expect(isScope(scope)).toBe(true);
  });

  it.each(["", "shared", "organization", "ALL"])(`rejects %s`, (scope) => {
    expect(isScope(scope)).toBe(false);
  });
});

describe("isRepository", () => {
  it("accepts an owner/repository name", () => {
    expect(isRepository("baleen37/knowledge-base")).toBe(true);
  });

  it.each(["../..", "owner/..", "./repo", "owner\\repo"])
    ("rejects unsafe repository name %s", (repository) => {
      expect(isRepository(repository)).toBe(false);
    });
});
