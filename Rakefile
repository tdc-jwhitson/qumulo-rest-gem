require "bundler/gem_tasks"
require "rake/testtask"
require 'minitest/ci'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "test/lib"
  t.test_files = FileList['test/ut/*_test.rb']
  t.verbose = (ENV['verbose'] == '1')
end

Rake::TestTask.new(:integration) do |t|
  t.libs << "test"
  t.libs << "test/lib"
  t.test_files = FileList['test/it/*_test.rb']
  t.verbose = (ENV['verbose'] == '1')
  t.description = "Run integration tests"
end

task :coverage do
  if RUBY_VERSION != "2.2.2"
    puts "Code coverage is only run on 2.2.2."
  else
    require "simplecov"
    SimpleCov.start
    Rake::Task["test"].execute
  end
end

