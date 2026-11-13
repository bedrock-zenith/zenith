import * as fs from "node:fs/promises";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Escapes a string to be a valid Zig/ZON string literal:
 * - Enclosed in double quotes `"`
 * - Escapes backslashes, double quotes, and control characters (\n, \r, \t)
 */
function escapeZonString(str: string): string {
  let escaped = "";
  for (let i = 0; i < str.length; i++) {
    const ch = str[i];
    switch (ch) {
      case "\\":
        escaped += "\\\\";
        break;
      case '"':
        escaped += '\\"';
        break;
      case "\n":
        escaped += "\\n";
        break;
      case "\r":
        escaped += "\\r";
        break;
      case "\t":
        escaped += "\\t";
        break;
      default: {
        const code = ch.charCodeAt(0);
        if (code < 0x20) {
          escaped += `\\x${code.toString(16).padStart(2, "0")}`;
        } else {
          escaped += ch;
        }
        break;
      }
    }
  }
  return `"${escaped}"`;
}

/**
 * Zig reserved keywords.
 */
const ZIG_KEYWORDS = new Set([
  "addrspace", "align", "allowzero", "and", "anyframe", "anytype", "asm",
  "async", "await", "break", "callconv", "catch", "comptime", "const",
  "continue", "defer", "errdefer", "error", "export", "extern", "fn",
  "for", "if", "inline", "noalias", "noinline", "nosuspend", "opaque",
  "or", "orelse", "packed", "pub", "resume", "return", "linksection",
  "struct", "suspend", "switch", "test", "threadlocal", "try", "type",
  "union", "unreachable", "usingnamespace", "var", "volatile", "while",
  "enum"
]);

/**
 * Checks whether an identifier can be written bare as `.ident` in ZON.
 * If not, it uses Zig identifier escape syntax `.@"..."`.
 */
function formatZonIdent(ident: string): string {
  if (/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(ident) && !ZIG_KEYWORDS.has(ident)) {
    return `.${ident}`;
  }
  return `.@"${ident.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

/**
 * Formats a key name in a ZON struct declaration.
 */
function formatZonKey(key: string): string {
  return formatZonIdent(key);
}

/**
 * Formats a value as a Zig enum literal (e.g., .numeric, .@"custom-enum").
 */
function formatZonEnumLiteral(value: string): string {
  return formatZonIdent(value);
}

/**
 * Rule configuration for converting string values into Zig enum literals.
 *
 * Supported options:
 * - `boolean`: If true, every string value for this key becomes an enum literal (.val).
 * - `string[]` / `Set<string>`: Only specific values become enum literals.
 * - `(val: string) => boolean | string | null | undefined`: Custom predicate or transformer.
 *   - Return `true`: formats original value as enum literal `.${val}`
 *   - Return a `string`: formats returned string as enum literal `.${result}`
 *   - Return `false` / `null`: keep standard string literal `"..."`
 */
export type EnumLiteralRule =
  | boolean
  | string[]
  | Set<string>
  | ((val: string) => boolean | string | null | undefined);

/**
 * Registry of keys whose values should be serialized as Zig enum literals.
 * Add or modify any keys here.
 */
export const ENUM_LITERAL_KEYS: Record<string, EnumLiteralRule> = {
  // e.g. "enum_kind": "numeric" -> .enum_kind = .numeric,
    enum_kind: true,
    bind_type: true,
    data_encoding: true,
  // You can easily add more keys here, e.g.:
  // bind_type: true,
  // backing_integer: true,
};

/**
 * Determines whether a string value for a given key should be rendered
 * as a Zig enum literal, and if so, returns the literal string name.
 */
function resolveEnumLiteral(key: string | undefined, value: string): string | null {
  if (!key) return null;
  const rule = ENUM_LITERAL_KEYS[key];
  if (!rule) return null;

  if (typeof rule === "boolean") {
    return rule ? value : null;
  }

  if (Array.isArray(rule)) {
    return rule.includes(value) ? value : null;
  }

  if (rule instanceof Set) {
    return rule.has(value) ? value : null;
  }

  if (typeof rule === "function") {
    const res = rule(value);
    if (typeof res === "string") return res;
    return res ? value : null;
  }

  return null;
}

/**
 * Serializes any JSON-compatible JavaScript value to ZON (Zig Object Notation).
 *
 * @param value The value to serialize.
 * @param indentLevel Indentation depth.
 * @param indentUnit String used for indentation (default: 4 spaces).
 * @param parentKey The object property name for this value (if applicable).
 */
export function stringifyZon(
  value: unknown,
  indentLevel = 0,
  indentUnit = "    ",
  parentKey?: string,
): string {
  const currentIndent = indentUnit.repeat(indentLevel);
  const nextIndent = indentUnit.repeat(indentLevel + 1);

  if (value === null || value === undefined) {
    return "null";
  }

  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }

  if (typeof value === "number") {
    if (Number.isFinite(value)) {
      return value.toString();
    }
    return "infinity";
  }

  if (typeof value === "string") {
    const enumLiteral = resolveEnumLiteral(parentKey, value);
    if (enumLiteral !== null) {
      return formatZonEnumLiteral(enumLiteral);
    }
    return escapeZonString(value);
  }

  if (Array.isArray(value)) {
    if (value.length === 0) {
      return ".{}";
    }
    const lines = value.map((item) => `${nextIndent}${stringifyZon(item, indentLevel + 1, indentUnit)},`);
    return `.{\n${lines.join("\n")}\n${currentIndent}}`;
  }

  if (typeof value === "object") {
    const entries = Object.entries(value);
    if (entries.length === 0) {
      return ".{}";
    }
    const lines = entries.map(([k, v]) => {
      const formattedKey = formatZonKey(k);
      const formattedVal = stringifyZon(v, indentLevel + 1, indentUnit, k);
      return `${nextIndent}${formattedKey} = ${formattedVal},`;
    });
    return `.{\n${lines.join("\n")}\n${currentIndent}}`;
  }

  throw new Error(`Unsupported value type: ${typeof value}`);
}

/**
 * Loads JSON protocol file and emits ZON equivalent.
 */
export async function convertJsonToZon(inputPath: string, outputPath: string): Promise<void> {
  console.log(`Reading: ${inputPath}`);
  const rawJson = await fs.readFile(inputPath, "utf-8");
  const data = JSON.parse(rawJson);

  console.log(`Serializing to ZON...`);
  const zonContent = `${stringifyZon(data)}\n`;

  console.log(`Writing: ${outputPath}`);
  await fs.writeFile(outputPath, zonContent, "utf-8");
  console.log(`Done! Output size: ${(zonContent.length / (1024 * 1024)).toFixed(2)} MB`);
}

// Support both ESM (import.meta.url) and CommonJS (__dirname) environments
const currentDir = typeof import.meta?.url === "string"
  ? path.dirname(fileURLToPath(import.meta.url))
  : (typeof __dirname !== "undefined" ? __dirname : process.cwd());

const defaultJsonPath = path.resolve(currentDir, "__protocol__.json");
const defaultZonPath = path.resolve(currentDir, "__protocol__.zon");

const inputPath = process.argv[2] ? path.resolve(process.argv[2]) : defaultJsonPath;
const outputPath = process.argv[3] ? path.resolve(process.argv[3]) : defaultZonPath;

await convertJsonToZon(inputPath, outputPath);
