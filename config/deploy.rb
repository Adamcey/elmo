# this deploy file makes use of the multistage facility of capistrano
# there are two stages:
# master - https://cceom.org; master branch; the main ELMO
# demo - https://secure1.cceom.org; demo branch; the staging environment and demo sandbox
# to deploy, e.g.:
#   cap demo deploy

require "bundler/capistrano" 

set :stages, %w(master demo)
set :default_stage, "demo"
require "capistrano/ext/multistage"

set :application, "elmo"
set :user, "cceom"
set :repository,  "https://code.google.com/p/elmo"
set(:deploy_to) {"/home/cceom/webapps/rails2/#{application}_#{stage}"}
set :deploy_via, :remote_cache
set :use_sudo, false
set :default_environment, {
  "PATH" => "$PATH:/home/cceom/bin:$HOME/webapps/rails2/bin",
  "GEM_HOME" => "$HOME/webapps/rails2/gems"
}
default_run_options[:pty] = true

# rails env is production for all stages
set :rails_env, 'production'

desc "Echo environment vars"
namespace :env do
  task :echo do
    run "echo printing out cap info on remote server"
    run "echo $PATH"
    run "printenv"
  end
end

server "cceom.org", :app, :web, :db, :primary => true

after 'deploy:update_code', 'deploy:migrate'

after "deploy", "deploy:cleanup" # keep only the last 5 releases

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} server"
    task command, roles: :app, except: {no_release: true} do
      run "/home/cceom/webapps/rails2/bin/#{command}"
    end
  end

  task :setup_config, roles: :app do
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.yml.example"), "#{shared_path}/config/database.yml"
    put File.read("config/initializers/local_config.rb.example"), "#{shared_path}/config/local_config.rb"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/config/local_config.rb #{release_path}/config/initializers/local_config.rb"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/#{branch}`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
  
  desc "ping the server so that it connects to db"
  task :ping, roles: :web do
    run "curl -s #{ping_url} > /dev/null"
  end
  after "deploy:restart", "deploy:ping"
  
  # override the assets precompilation task to check if assets need to be precompiled
  namespace :assets do
    task :precompile, :roles => :web, :except => { :no_release => true } do
      from = source.next_revision(current_revision)
      if releases.length <= 1 || capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ lib/assets/ app/assets/ | wc -l").to_i > 0
        run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:precompile}
      else
        logger.info "Skipping asset pre-compilation because there were no asset changes"
      end
    end
  end
end