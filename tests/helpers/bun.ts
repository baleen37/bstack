/**
 * Bun test helper for claude-plugins project
 * TypeScript equivalent of bats_helper.bash
 */

import { readFileSync, existsSync, readdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

// Get the current file path and resolve project root
const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// Resolve PROJECT_ROOT: tests/helpers/bun.ts -> tests/ -> project_root
export const PROJECT_ROOT = dirname(dirname(__dirname))

// Export common paths
export const PLUGINS_DIR = join(PROJECT_ROOT, 'plugins')

// Allowed fields in plugin.json
const ALLOWED_FIELDS = new Set([
  'name',
  'description',
  'author',
  'version',
  'license',
  'homepage',
  'repository',
  'keywords',
  'lspServers',
])

// Allowed author fields
const ALLOWED_AUTHOR_FIELDS = new Set(['name', 'email'])

/**
 * Plugin manifest interface
 */
export interface PluginManifest {
  name: string
  description: string
  author: AuthorInfo | string
  version?: string
  license?: string
  homepage?: string
  repository?: string
  keywords?: string[]
  lspServers?: string[]
}

/**
 * Author information interface
 */
interface AuthorInfo {
  name?: string
  email?: string
}

/**
 * Validate JSON file - returns parsed data or throws
 */
export function validateJson<T = unknown>(path: string): T {
  try {
    const content = readFileSync(path, 'utf-8')
    return JSON.parse(content) as T
  } catch (error) {
    throw new Error(`Invalid JSON in ${path}: ${error instanceof Error ? error.message : String(error)}`)
  }
}

/**
 * Assert value is not empty with optional custom message
 */
export function assertNotEmpty(value: string, message?: string): void {
  if (!value || value.trim().length === 0) {
    throw new Error(message || 'Value should not be empty')
  }
}

/**
 * Check if plugin name follows naming convention
 * Must be lowercase with hyphens and numbers only
 */
export function isValidPluginName(name: string): boolean {
  return /^[a-z0-9-]+$/.test(name)
}

/**
 * Assert plugin name is valid
 */
export function assertValidPluginName(name: string): void {
  if (!isValidPluginName(name)) {
    throw new Error(`Invalid plugin name '${name}'. Must be lowercase with hyphens and numbers only.`)
  }
}

/**
 * Check if JSON field is allowed in plugin.json
 */
export function isJsonFieldAllowed(field: string): boolean {
  return ALLOWED_FIELDS.has(field)
}

/**
 * Check if author field is allowed
 */
export function isAuthorFieldAllowed(field: string): boolean {
  return ALLOWED_AUTHOR_FIELDS.has(field)
}

/**
 * Validate plugin manifest has only allowed fields
 */
export function validatePluginManifestFields(manifest: PluginManifest, path: string): void {
  const fields = Object.keys(manifest)

  for (const field of fields) {
    if (!isJsonFieldAllowed(field)) {
      throw new Error(
        `Invalid field '${field}' in ${path}. Allowed fields: ${Array.from(ALLOWED_FIELDS).join(', ')}`
      )
    }
  }

  // Check nested author fields if author is an object
  if (manifest.author && typeof manifest.author === 'object') {
    const authorFields = Object.keys(manifest.author)
    for (const field of authorFields) {
      if (!isAuthorFieldAllowed(field)) {
        throw new Error(
          `Invalid author field 'author.${field}' in ${path}. Allowed author fields: ${Array.from(ALLOWED_AUTHOR_FIELDS).join(', ')}`
        )
      }
    }
  }
}

/**
 * Get all plugin manifest paths
 * Includes both root canonical plugin and plugins directory plugins.
 */
export function getAllPluginManifests(): string[] {
  const manifests: string[] = []

  // Check for root canonical plugin
  const rootManifestPath = join(PROJECT_ROOT, '.claude-plugin', 'plugin.json')
  if (existsSync(rootManifestPath)) {
    manifests.push(rootManifestPath)
  }

  try {
    const plugins = readdirSync(PLUGINS_DIR, { withFileTypes: true })

    for (const plugin of plugins) {
      if (plugin.isDirectory()) {
        const manifestPath = join(PLUGINS_DIR, plugin.name, '.claude-plugin', 'plugin.json')
        if (existsSync(manifestPath)) {
          manifests.push(manifestPath)
        }
      }
    }
  } catch (error) {
    // Plugins directory might not exist
  }

  return manifests
}

/**
 * Parse and cache plugin manifests
 */
export function parsePluginManifest(path: string): PluginManifest {
  return validateJson<PluginManifest>(path)
}

