# Changelog

## [0.2.3](https://github.com/fpsvogel/pipeful/releases/tag/0.2.3)

- Added a Pipeful.array to collect results of a pipeline.

## [0.2.2](https://github.com/fpsvogel/pipeful/releases/tag/0.2.2)

- Fixed a bug where multiple mixins broke eval mode.
- Replaced internal monkey patches with extensions and refinements.

## [0.2.1](https://github.com/fpsvogel/pipeful/releases/tag/0.2.1)

- Reverted to the previous `method_missing` approach (simpler and more flexible) while ensuring that custom `method_missing`s still work in the new test cases.

## [0.2.0](https://github.com/fpsvogel/pipeful/releases/tag/0.2.0)

- Not using `method_missing` anymore. See [Issue #1](https://github.com/fpsvogel/pipeful/issues/1).
- Bug fixed where functions called with parenthetical arguments caused an `ArgumentError` if the number of items in the pipeline exceeded the arity of the function, because the function took all of them as arguments.

## [0.1.2](https://github.com/fpsvogel/pipeful/releases/tag/0.1.2)

- Separated positional and keyword arguments in method_missing, so that this will work in Ruby 3: `... >> AttackUser(mode: :stun)`. Keyword arguments still cannot be piped, however, as this would require a separate pipe buffer and would add complexity to the DSL.

## [0.1.1](https://github.com/fpsvogel/pipeful/releases/tag/0.1.1)

- Initial release.
