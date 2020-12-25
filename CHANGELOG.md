# Changelog

## [0.2.0](https://github.com/fps-vogel/pipeful/releases/tag/0.2.0)

- `method_missing` can now be used along with piping. See [Issue #1](https://github.com/fps-vogel/pipeful/issues/1).
- Bug fixed where functions called with parenthetical arguments caused an `ArgumentError` if the number of items in the pipeline exceeded the arity of the function, because the function took all of them as arguments.

## [0.1.2](https://github.com/fps-vogel/pipeful/releases/tag/0.1.2)

- Separated positional and keyword arguments in method_missing, so that this will work in Ruby 3: `... >> AttackUser(mode: :stun)`. Keyword arguments still cannot be piped, however, as this would require a separate pipe buffer and would add complexity to the DSL.

## [0.1.1](https://github.com/fps-vogel/pipeful/releases/tag/0.1.1)

- Initial release.
