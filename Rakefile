require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "test/lib"
  t.test_files = FileList['test/ut/*_test.rb']
  t.verbose = (ENV['verbose'] == '1')
end

Rake::TestTask.new(:integration) do |t|
  t.libs << "test"
  t.test_files = FileList['test/it/*_test.rb']
  t.verbose = (ENV['verbose'] == '1')
  t.description = "Run integration tests"
end

