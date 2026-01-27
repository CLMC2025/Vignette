/**
 * ArkTS Compliance Configuration Manager
 * Handles project-specific rule configurations
 */

import { readFileSync } from 'fs';
import { parse } from 'yaml';
import { Rule, RULES, Severity } from './rules';

export interface Config {
  rules: {
    [key: string]: {
      enabled?: boolean;
      severity?: Severity;
    };
  };
  exclude: string[];
  namingConventions: {
    componentNames?: string;
    functionNames?: string;
    constantNames?: string;
    typeNames?: string;
  };
}

export class ConfigManager {
  private defaultConfig: Config = {
    rules: {},
    exclude: [
      'node_modules',
      'build',
      '.preview',
      'oh_modules'
    ],
    namingConventions: {
      componentNames: 'PascalCase',
      functionNames: 'camelCase',
      constantNames: 'UPPER_SNAKE_CASE',
      typeNames: 'PascalCase'
    }
  };

  private config: Config;

  constructor(configPath?: string) {
    this.config = this.loadConfig(configPath);
  }

  /**
   * Load configuration from file or use default
   */
  private loadConfig(configPath?: string): Config {
    if (configPath) {
      try {
        const content = readFileSync(configPath, 'utf-8');
        const userConfig = parse(content) as Partial<Config>;
        return {
          ...this.defaultConfig,
          ...userConfig,
          rules: {
            ...this.defaultConfig.rules,
            ...userConfig.rules
          },
          exclude: [
            ...this.defaultConfig.exclude,
            ...(userConfig.exclude || [])
          ],
          namingConventions: {
            ...this.defaultConfig.namingConventions,
            ...(userConfig.namingConventions || {})
          }
        };
      } catch (error) {
        console.warn(`Warning: Could not load config file ${configPath}. Using default configuration.`);
        return this.defaultConfig;
      }
    }
    return this.defaultConfig;
  }

  /**
   * Get the final set of rules with user overrides
   */
  getRules(): Rule[] {
    return RULES.map(rule => {
      const userRuleConfig = this.config.rules[rule.id];
      if (userRuleConfig) {
        return {
          ...rule,
          enabled: userRuleConfig.enabled ?? rule.enabled,
          severity: userRuleConfig.severity ?? rule.severity
        };
      }
      return rule;
    });
  }

  /**
   * Get excluded directories
   */
  getExcludedDirs(): string[] {
    return this.config.exclude;
  }

  /**
   * Get naming conventions
   */
  getNamingConventions() {
    return this.config.namingConventions;
  }

  /**
   * Create default configuration file
   */
  getDefaultConfigContent(): string {
    return `# ArkTS Compliance Configuration
# This file defines project-specific coding rules

rules:
  # Syntax rules
  no-any-unknown:
    severity: error
    enabled: true
  no-destructuring:
    severity: error
    enabled: true
  no-param-destructuring:
    severity: error
    enabled: true
  no-inline-object-types:
    severity: error
    enabled: true
  valid-property-names:
    severity: error
    enabled: true

  # Naming conventions
  component-names:
    severity: error
    enabled: true
  function-names:
    severity: error
    enabled: true
  constant-names:
    severity: error
    enabled: true

  # UI component rules
  ui-in-model:
    severity: error
    enabled: true
  no-on-finish:
    severity: error
    enabled: true
  no-ease-out-back:
    severity: warning
    enabled: true
  no-spring-curve:
    severity: warning
    enabled: true

  # Performance rules
  foreach-key:
    severity: error
    enabled: true

  # Type safety rules
  explicit-return-types:
    severity: error
    enabled: true

exclude:
  - node_modules
  - build
  - .preview
  - oh_modules

namingConventions:
  componentNames: PascalCase
  functionNames: camelCase
  constantNames: UPPER_SNAKE_CASE
  typeNames: PascalCase
`;
  }
}