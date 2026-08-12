import antfu from '@antfu/eslint-config'

export default antfu({
  ignores: ['mise.toml', 'mods/*/src/_typings/**', 'packages/vidot/runtime/src/_typings/**', 'packages/vikeeper/runtime/src/_typings/**'],
}, {
  files: ['packages/vidot/**/*.ts', 'packages/vikeeper/**/*.ts', 'examples/basic-vidot/**/*.ts'],
  rules: {
    'style/padding-line-between-statements': ['error', { blankLine: 'always', prev: 'if', next: '*' }, { blankLine: 'always', prev: '*', next: 'return' }],
  },
}, {
  files: ['packages/vidot/runtime/src/**/*.ts', 'packages/vikeeper/runtime/src/**/*.ts'],
  rules: {
    'object-shorthand': 'off',
  },
})
