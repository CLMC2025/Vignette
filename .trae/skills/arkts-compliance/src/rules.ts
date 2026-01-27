/**
 * ArkTS Compliance Rule Definitions
 * Defines all coding rules for ArkTS/ETS files
 */

export enum Severity {
  ERROR = 'error',
  WARNING = 'warning',
  INFO = 'info'
}

export interface Rule {
  id: string;
  name: string;
  description: string;
  severity: Severity;
  category: string;
  pattern: RegExp;
  fixSuggestion: string;
  enabled: boolean;
}

export const RULES: Rule[] = [
  // Syntax Rules
  {
    id: 'no-any-unknown',
    name: 'No any/unknown types',
    description: 'Avoid using any or unknown types unless explicitly justified',
    severity: Severity.ERROR,
    category: 'syntax',
    pattern: /(any|unknown)\s*(?=:|>|\[|\))/g,
    fixSuggestion: 'Replace with explicit type or use a proper interface',
    enabled: true
  },
  {
    id: 'no-destructuring',
    name: 'No destructuring assignment/declaration',
    description: 'Destructuring is not supported in strict ArkTS mode',
    severity: Severity.ERROR,
    category: 'syntax',
    pattern: /\{[^}]+\}\s*=|\[[^\]]+\]\s*=/g,
    fixSuggestion: 'Use direct property access instead',
    enabled: true
  },
  {
    id: 'no-param-destructuring',
    name: 'No parameter destructuring',
    description: 'Parameter destructuring is not supported in strict ArkTS mode',
    severity: Severity.ERROR,
    category: 'syntax',
    pattern: /\([^)]*\{[^)]*\}\)/g,
    fixSuggestion: 'Use individual parameters instead',
    enabled: true
  },
  {
    id: 'no-inline-object-types',
    name: 'No inline object type declarations',
    description: 'Use explicit interfaces or classes instead of inline object types',
    severity: Severity.ERROR,
    category: 'syntax',
    pattern: /:\s*\{[^}]+\}/g,
    fixSuggestion: 'Create an explicit interface or class for this object type',
    enabled: true
  },
  {
    id: 'valid-property-names',
    name: 'Valid property names',
    description: 'Object property names must be valid identifiers',
    severity: Severity.ERROR,
    category: 'syntax',
    pattern: /'[^']+'\s*:/g,
    fixSuggestion: 'Use valid identifiers as property names',
    enabled: true
  },

  // Naming Conventions
  {
    id: 'component-names',
    name: 'Component names must be PascalCase',
    description: 'Component classes must use PascalCase naming',
    severity: Severity.ERROR,
    category: 'naming',
    pattern: /@Component\s+struct\s+[a-z][A-Za-z0-9]*/g,
    fixSuggestion: 'Rename component to PascalCase',
    enabled: true
  },
  {
    id: 'function-names',
    name: 'Function names must be camelCase',
    description: 'Function names must use camelCase naming',
    severity: Severity.ERROR,
    category: 'naming',
    pattern: /function\s+[A-Z][A-Za-z0-9]*|const\s+[A-Z][A-Za-z0-9]*\s*=/g,
    fixSuggestion: 'Rename function to camelCase',
    enabled: true
  },
  {
    id: 'constant-names',
    name: 'Constant names must be UPPER_SNAKE_CASE',
    description: 'Constants must use UPPER_SNAKE_CASE naming',
    severity: Severity.ERROR,
    category: 'naming',
    pattern: /const\s+[a-z][A-Za-z0-9]*\s*=/g,
    fixSuggestion: 'Rename constant to UPPER_SNAKE_CASE',
    enabled: true
  },

  // UI Component Rules
  {
    id: 'ui-in-model',
    name: 'No UI DSL in model/algorithm files',
    description: 'UI component syntax should only be in UI files',
    severity: Severity.ERROR,
    category: 'ui',
    pattern: /(Column|Row|Text|Stack|ForEach|@Builder)\(/g,
    fixSuggestion: 'Move UI code to proper UI component files',
    enabled: true
  },
  {
    id: 'no-on-finish',
    name: 'No onFinish property',
    description: 'The onFinish property is not supported on all components',
    severity: Severity.ERROR,
    category: 'ui',
    pattern: /\.onFinish\(/g,
    fixSuggestion: 'Use supported lifecycle methods or callbacks instead',
    enabled: true
  },
  {
    id: 'no-ease-out-back',
    name: 'No Curve.EaseOutBack',
    description: 'Curve.EaseOutBack is not supported in all ArkTS versions',
    severity: Severity.WARNING,
    category: 'ui',
    pattern: /Curve\.EaseOutBack/g,
    fixSuggestion: 'Use Curve.EaseOutCubic or other supported curves',
    enabled: true
  },
  {
    id: 'no-spring-curve',
    name: 'No Curve.Spring',
    description: 'Curve.Spring is not supported in all ArkTS versions',
    severity: Severity.WARNING,
    category: 'ui',
    pattern: /Curve\.Spring/g,
    fixSuggestion: 'Use Curve.Bezier with spring-like parameters',
    enabled: true
  },

  // Performance Rules
  {
    id: 'foreach-key',
    name: 'ForEach must have key attribute',
    description: 'ForEach loops must include a key attribute for performance',
    severity: Severity.ERROR,
    category: 'performance',
    pattern: /ForEach\(\s*[^,]+,\s*[^,]+(?!,\s*\{[^}]*key:)/g,
    fixSuggestion: 'Add a key attribute to the ForEach loop',
    enabled: true
  },

  // Type Safety Rules
  {
    id: 'explicit-return-types',
    name: 'Explicit return types',
    description: 'Functions must have explicit return types',
    severity: Severity.ERROR,
    category: 'type-safety',
    pattern: /function\s+[a-zA-Z0-9_]+\s*\([^)]*\)\s*(?={)/g,
    fixSuggestion: 'Add explicit return type annotation',
    enabled: true
  }
];