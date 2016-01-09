require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
# require 'mina/rbenv'  # for rbenv support. (http://rbenv.org)
require 'mina/rvm'    # for rvm support. (http://rvm.io)

['base', 'nginx', 'check'].each do |pkg|
  require "#{File.join(__dir__, 'recipes', "#{pkg}")}"
end


set :application, 'unicorn_app'
set :user, set_user
set :deploy_to, "/home/#{user}/#{application}"
# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

# set :domain, 'foobar.com'
set :repository, 'https://ramlaxmanyadav:RamLaxman9@github.com/ramlaxmanyadav/unicorn_app.git'
set :branch, 'master'

set :ruby_version, "#{File.readlines(File.join(__dir__, '..', '.ruby-version')).first.strip}"
set :gemset, "#{File.readlines(File.join(__dir__, '..', '.ruby-gemset')).first.strip}"
# For system-wide RVM install.
#   set :rvm_path, '/usr/local/rvm/bin/rvm'

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, [
                     'config/database.yml', 'log', 'config/secrets.yml']
# Optional settings:
#   set :user, 'foobar'    # Username in the server to SSH to.
#   set :port, '30000'     # SSH port number.
#   set :forward_agent, true     # SSH forward_agent.

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  set :rails_env, ENV['on'].to_sym unless ENV['on'].nil?
  # For those using RVM, use this to load an RVM version@gemset.
  require "#{File.join(__dir__, 'deploy', "#{rails_env}_configurations_files", 'settings.rb')}"
  invoke :"rvm:use[ruby-#{ruby_version}@#{gemset}]"
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  invoke :set_sudo_password
  queue! %[mkdir "#{deploy_to}"]
  queue! %[chown -R "#{user}" "#{deploy_to}"]

  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[mkdir -p "#{deploy_to}/shared/pids"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/pids"]

  invoke :setup_yml
  queue %[echo "-----> Be sure to edit 'shared/config/database.yml'."]
  invoke :setup_prerequesties
end

task :setup_prerequesties => :environment do
  queue 'echo "-----> Installing development dependencies"'
  [
      'python-software-properties', 'libmysqlclient-dev', 'imagemagick', 'libmagickwand-dev', 'nodejs',
      'build-essential', 'zlib1g-dev', 'libssl-dev', 'libreadline-dev', 'libyaml-dev', 'libcurl4-openssl-dev', 'curl',
      'git-core', 'libreoffice', 'make', 'gcc', 'g++', 'pkg-config', 'libfuse-dev', 'libxml2-dev', 'zip', 'libtool',
      'xvfb', 'mime-support', 'automake', 'memcached', 'nginx'
  ].each do |package|
    puts "Installing #{package}"
    queue! %[sudo -A apt-get install -y #{package}]
  end

  queue 'echo "-----> Installing Ruby Version Manager"'
  queue! %[command curl -sSL https://rvm.io/mpapis.asc | gpg --import]
  queue! %[curl -sSL https://get.rvm.io | bash -s stable --ruby]

  queue! %[source "#{rvm_path}"]
  queue! %[rvm requirements]
  queue! %[rvm install "#{ruby_version}"]
  invoke :"rvm:use[#{ruby_version}@#{gemset}]"
  queue! %[gem install bundler]

  queue! %[mkdir "#{deploy_to}"]
  queue! %[chown -R "#{user}" "#{deploy_to}"]
  # #setup nginx
  invoke :'nginx:install'
  # #setup nginx
  invoke :'nginx:setup'
  invoke :'nginx:restart'

end

task :setup_yml => :environment do
  Dir[File.join(__dir__, '*.example.yml')].each do |_path|
    queue! %[echo "#{erb _path}" > "#{File.join(deploy_to, 'shared/config', File.basename(_path, '.example.yml') +'.yml')}"]
  end
end


desc "Deploys the current version to the server."
task :deploy => :environment do
  to :before_hook do
    # Put things to run locally before ssh
  end
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    invoke :'deploy:cleanup'

    to :launch do
      queue "mkdir -p #{deploy_to}/#{current_path}/tmp/"
      queue "touch #{deploy_to}/#{current_path}/tmp/restart.txt"
    end
  end
end

task :set_sudo_password => :environment do
  queue! "echo '#{erb(File.join(__dir__, 'deploy', "#{rails_env}_configurations_files", 'sudo_password.erb'))}' > /home/#{user}/SudoPass.sh"
  queue! "chmod +x /home/#{user}/SudoPass.sh"
  queue! "export SUDO_ASKPASS=/home/#{user}/SudoPass.sh"
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers
