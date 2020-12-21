$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "pipeful"
require "pipeful/version"

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use!
