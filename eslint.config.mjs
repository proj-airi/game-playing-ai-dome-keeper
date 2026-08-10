import antfu from '@antfu/eslint-config'

export default antfu({
  ignores: ['mise.toml', '**/.vidot-session.json', 'mods/*/src/_typings/**', 'mods/*/test/godot/_typings/**', 'packages/vidot/runtime/src/_typings/**'],
}, {
  files: ['packages/vidot/**/*.ts', 'examples/basic-vidot/**/*.ts'],
  rules: {
    'style/padding-line-between-statements': ['error', { blankLine: 'always', prev: 'if', next: '*' }, { blankLine: 'always', prev: '*', next: 'return' }],
  },
}, {
  files: ['packages/vidot/runtime/src/**/*.ts'],
  rules: {
    'object-shorthand': 'off',
  },
})
