require "bundler/gem_tasks"
require "rake/testtask"

task default: :test

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/pipeful_test.rb"]
end

# Rake::TestTask.new(:test) do |t|
#   t.libs << "test"
#   t.libs << "lib"
#   t.test_files = FileList["test/**/*_test.rb"]
# end

# task :default => :test
