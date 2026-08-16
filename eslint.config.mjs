import antfu from '@antfu/eslint-config'

export default antfu({
  ignores: ['mise.toml', '**/src/_typings/**'],
}, {
  files: [
    'packages/vidot/runtime/src/**/*.ts',
    'packages/vikeeper/runtime/src/**/*.ts',
  ],
  rules: {
    'style/padding-line-between-statements': ['error', { blankLine: 'always', prev: 'if', next: '*' }, { blankLine: 'always', prev: '*', next: 'return' }],
    'object-shorthand': 'off',
  },
})
