// Recommended ESLint flat-config fragment of the linter-driven-development
// plugins: every rule the plugin's routing table routes to one of the twelve
// design rules, at the limits the rules name. Each rule line says which rule its
// failures feed. The plugin never writes this file into a repository: the
// repository's owners copy it, or the parts they want, beside eslint.config.js
// and spread it before their own entries. Later entries win, so every limit the
// repository's config already sets stays the repository's:
//
//   import ldd from './eslint.config.ldd.mjs'
//   export default [...ldd, ...yourConfig]
//
// residue-exempt: an ESLint configuration names its plugins and rules on purpose.
// It needs eslint-plugin-sonarjs, eslint-plugin-react, eslint-plugin-react-hooks,
// eslint-plugin-promise, eslint-plugin-import and typescript-eslint; a repository
// that does not use one of them leaves its rules out. The @typescript-eslint rules
// below need type information: the repository's config sets typescript-eslint's
// parser with parserOptions.projectService for these files, or ESLint stops with
// an error. Limits a repository already sets stay the repository's: the linter is
// the authority for every threshold it holds. Rules this file leaves out (style,
// imports, formatting) are the repository's own choice, and so is
// no-restricted-syntax on import.meta.env outside the config module (R8): the
// config module's path is the repository's.
//
// Adopt it on an existing codebase with ESLint's bulk suppressions: run
// `npx eslint --suppress-all` once to record today's violations, so only new ones
// fail; `npx eslint --prune-suppressions` drops the entries that are fixed.

import importPlugin from 'eslint-plugin-import'
import promise from 'eslint-plugin-promise'
import react from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import sonarjs from 'eslint-plugin-sonarjs'
import tseslint from 'typescript-eslint'

export default [
  {
    files: ['**/*.{ts,tsx}'],
    plugins: {
      '@typescript-eslint': tseslint.plugin,
      import: importPlugin,
      promise,
      react,
      'react-hooks': reactHooks,
      sonarjs,
    },
    rules: {
      // R3 storifying
      'sonarjs/cognitive-complexity': ['error', 15],
      'sonarjs/cyclomatic-complexity': ['error', { threshold: 10 }],
      'sonarjs/expression-complexity': ['error', { max: 5 }],
      'sonarjs/max-lines-per-function': ['error', { maximum: 200 }],
      'sonarjs/nested-control-flow': ['error', { maximumNestingLevel: 4 }],
      'sonarjs/no-nested-conditional': 'error',
      'sonarjs/no-nested-functions': 'error',
      'sonarjs/elseif-without-else': 'error',
      'react/no-unstable-nested-components': 'error',
      // R1 primitive obsession
      'max-params': ['error', 4],
      'sonarjs/no-duplicate-string': ['error', { threshold: 3 }],
      'sonarjs/max-union-size': ['error', { threshold: 4 }],
      'sonarjs/no-identical-functions': 'error',
      'react/no-array-index-key': 'error',
      'no-magic-numbers': ['error', {
        ignore: [-1, 0, 1, 2],
        ignoreArrayIndexes: true,
        ignoreDefaultValues: true,
        ignoreClassFieldInitialValues: true,
        detectObjects: false,
      }],
      // R2 self-validating types: parse at the boundary
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-non-null-assertion': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/no-unnecessary-condition': 'error',
      // R5 vertical slice: one juicy module per file; counts code lines only
      'sonarjs/max-lines': ['error', { maximum: {{.FileMaxLines}} }],
      'react/no-multi-comp': ['error', { ignoreStateless: false }],
      // R8 no globals
      'import/no-mutable-exports': 'error',
      // R10 concurrency safety
      'react-hooks/exhaustive-deps': 'error',
      'react-hooks/set-state-in-effect': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      'promise/catch-or-return': 'error',
      // R11 conditional dispatch
      '@typescript-eslint/switch-exhaustiveness-check': 'error',
      'sonarjs/no-nested-switch': 'error',
      'sonarjs/max-switch-cases': 'error',
      'sonarjs/no-small-switch': 'error',
      // R12 mutation discipline
      'no-param-reassign': ['error', { props: true }],
      'sonarjs/prefer-read-only-props': 'error',
      'react/no-direct-mutation-state': 'error',
    },
  },
  {
    // Tests are long and repeat literals by design.
    files: ['**/*.test.{ts,tsx}', '**/*.spec.{ts,tsx}'],
    rules: {
      'sonarjs/max-lines-per-function': 'off',
      'sonarjs/no-duplicate-string': 'off',
      'sonarjs/no-nested-functions': 'off',
      'max-params': 'off',
      'no-magic-numbers': 'off',
      'react/no-multi-comp': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
    },
  },
]
