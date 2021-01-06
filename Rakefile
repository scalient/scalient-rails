# frozen_string_literal: true

# Adapted from `https://github.com/rspec/rspec-rails/blob/main/lib/rspec/rails/tasks/rspec.rake`.

if defined?(Rails)
  require_relative "config/environment"

  app = Rails.application
  app.load_tasks

  # Change the working directory to the putative Rails app root, because some Rake tasks may use relative paths.
  Dir.chdir app.root
else
  require "pathname"
  require "rspec/core/rake_task"
  require "active_record"

  app_root = Pathname.new("../spec/support/test_app").expand_path(__FILE__)

  # Adapt rspec-rails tasks for our app-less environment.

  task default: :spec

  desc "Run all specs in spec directory (excluding plugin specs)"
  RSpec::Core::RakeTask.new(spec: "spec:prepare")

  namespace :spec do
    types =
        begin
          dirs = Dir["./spec/**/*_spec.rb"].
              map { |f| f.sub(/^\.\/(spec\/\w+)\/.*/, "\\1") }.
              uniq.
              select { |f| File.directory?(f) }
          Hash[dirs.map { |d| [d.split("/").last, d] }]
        end

    task :prepare do
      ENV["RACK_ENV"] = ENV["RAILS_ENV"] = "test"
    end

    types.each do |type, dir|
      desc "Run the code examples in #{dir}"
      RSpec::Core::RakeTask.new(type => "spec:prepare") do |t|
        t.pattern = "./#{dir}/**/*_spec.rb"
      end
    end
  end

  # Adapt ActiveRecord tasks for our app-less environment.

  include ActiveRecord::Tasks

  DatabaseTasks.env = "test"
  DatabaseTasks.database_configuration = YAML.load((app_root + "config/database.yml").open("rb") { |f| f.read })
  DatabaseTasks.db_dir = app_root + "db"
  DatabaseTasks.migrations_paths = [app_root + "db/migrate"]
  DatabaseTasks.root = app_root

  task :environment do
    ActiveRecord::Base.configurations = DatabaseTasks.database_configuration
    ActiveRecord::Base.establish_connection DatabaseTasks.env.to_sym
  end

  load "active_record/railties/databases.rake"
end
