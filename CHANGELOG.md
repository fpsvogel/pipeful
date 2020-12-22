# Changelog

## [0.1.2](https://github.com/fps-vogel/pipeful/releases/tag/0.1.2)

- Separated positional and keyword arguments in method_missing, so that this will work in Ruby 3: `... >> AttackUser(mode: :stun)`. Keyword arguments still cannot be piped, however, as this would require a separate pipe buffer and would add complexity to the DSL.

## [0.1.1](https://github.com/fps-vogel/pipeful/releases/tag/0.1.1)

- Initial release.
