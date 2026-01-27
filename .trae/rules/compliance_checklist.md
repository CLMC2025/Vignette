# ArkTS Strict Compliance Checklist

## Core Rules (From project_rules.md)

### 1. Technology Stack Restrictions
- [ ] Only ArkTS + ArkUI(ETS) allowed
- [ ] No React/Vue/Node/DOM paradigms
- [ ] Only import symbols resolvable by IDE

### 2. UI Component Rules
- [ ] UI syntax only in `@Entry @Component struct` build() methods
- [ ] No UI DSL in manager/algorithm/model files
- [ ] No @Builder functions in non-UI files

### 3. Type System Strictness
- [ ] No `any`/`unknown` types
- [ ] All parameters have explicit types
- [ ] All return values have explicit types
- [ ] No destructuring assignment/declaration
- [ ] No parameter destructuring

### 4. Object Literal Rules
- [ ] No inline object type declarations
- [ ] All object literals match explicit interfaces/classes
- [ ] `map()` returns typed objects (not untyped literals)
- [ ] No object properties with quotes or special characters

### 5. Animation API Rules
- [ ] Only verified ArkUI animation APIs
- [ ] No Curve.EaseOutBack/Curve.Spring (unless verified)
- [ ] No onFinish chained calls on components
- [ ] Use animateTo callbacks or Promise wrappers instead

### 6. Other Rules
- [ ] No Set<string> passed directly to string parameters
- [ ] Explicit type conversion when needed
- [ ] All code compiles without errors

## File-by-File Compliance Status

| File | Status | Issues |
|------|--------|--------|
| WordModel.ets | ✅ | No major issues |
| DBManager.ets | ✅ | No major issues |
| DataSyncManager.ets | ✅ | No major issues |
| SessionPlanner.ets | ✅ | No major issues |
| ContextValidator.ets | ✅ | No major issues |
| Animations.ets | ❌ | Curve types, UI syntax |
| EnhancedCards.ets | ❌ | Imports, UI syntax |
| ProgressCharts.ets | ❌ | Nested functions, Progress props |
| AdaptiveDifficulty.ets | ❌ | Object literals |
| UserAssessment.ets | ❌ | Object literals |
| ReadPage.ets | ❌ | Destructuring, Set usage |
| DictionaryManager.ets | ❌ | API response types |

## Implementation Plan

1. **Fix Type System Issues**
   - Remove all any/unknown types
   - Add explicit types to all parameters/returns
   - Replace destructuring with direct access

2. **Fix Object Literal Issues**
   - Create interfaces for all object structures
   - Replace inline types with explicit interfaces
   - Fix property names in objects

3. **Fix UI Component Issues**
   - Remove UI DSL from non-UI files
   - Fix animation API usage
   - Fix Progress component properties

4. **Fix Other Issues**
   - Fix Set<string> usage
   - Fix API response handling
   - Fix nested functions

5. **Verify Compliance**
   - Run diagnostics after each fix
   - Check against this checklist
   - Ensure no new errors introduced