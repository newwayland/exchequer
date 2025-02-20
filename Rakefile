# frozen_string_literal: true

require 'rake'

IMAGE_NAME='simulation'

def run_in_container(command = nil)
  sh "podman run -it --rm --mount type=bind,source=${PWD}/log,destination=/app/log --name rake-run #{IMAGE_NAME} #{command}"
end

namespace :rbs do
  desc 'Generate RBS files'
  task generate: ['mode:test', 'build'] do
    run_in_container 'rbs collection install'
  end

  desc 'Run type checker'
  task check: ['mode:test', 'build'] do
    run_in_container 'steep check'
  end
end

namespace :mode do
  desc 'production mode'
  task :production do
    sh 'bundle config unset --local with'
  end

  desc 'test mode'
  task :test do
    sh 'bundle config set --local with test'
  end
end

namespace :test do
  desc 'Run tests inside the container'
  task run: ['mode:test', 'build'] do
    run_in_container 'rspec'
  end
end

desc "Build #{IMAGE_NAME}"
task :build do
  sh "podman build -t #{IMAGE_NAME} ."
  sh "podman system prune -f"
end

desc "Run #{IMAGE_NAME}"
task run: ['mode:production', 'build'] do
  run_in_container
end

desc 'Run all checks and tests'
task default: ['rbs:check', 'test:run']
