#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";
import { join, sep } from "node:path";

const [settingsPath] = process.argv.slice(2);

if (!settingsPath) {
  console.error("Usage: configure-handoff-directory.mjs <settings.json>");
  process.exit(2);
}

const dataHome = process.env.XDG_DATA_HOME
  || (process.env.HOME && join(process.env.HOME, ".local", "share"));

if (!dataHome) {
  console.error("HOME or XDG_DATA_HOME is required");
  process.exit(2);
}

const settings = JSON.parse(readFileSync(settingsPath, "utf8"));
settings.permissions ??= {};

const directories = Array.isArray(settings.permissions.additionalDirectories)
  ? settings.permissions.additionalDirectories
  : [];
const isManagedHandoffDirectory = (directory) => (
  typeof directory === "string" && /(?:^|\/)bstack\/handoff\/?$/.test(directory)
);
const handoffDirectory = `${join(dataHome, "bstack", "handoff")}${sep}`;

settings.permissions.additionalDirectories = [
  ...directories.filter((directory) => !isManagedHandoffDirectory(directory)),
  handoffDirectory,
];

writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);
