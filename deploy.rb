require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
# require 'mina/rbenv'  # for rbenv support. (http://rbenv.org)
require 'mina/rvm' # for rvm support. (http://rvm.io)
require 'yaml'
# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set_default :domain, '192.241.225.185'
set_default :branch, 'master'
set_default :user, 'deploy'
#set_default :port, 10016
set_default :cert_path, ''
set_default :cert_key_path, ''
set :rails_env, :development

set :deploy_to, '/home/deploy/ugli'
set :repository, 'https://nitanshu1991:Nitanshu71@git.assembla.com/papayaheaderlabs.ugli.git'
set :ruby_version, "#{File.readlines(File.join(__dir__, '..', '.ruby-version')).first.strip}"
set :gemset, "#{File.readlines(File.join(__dir__, '..', '.ruby-gemset')).first.strip}"
set :application, 'ugli'

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, [
                     'config/database.yml', 'log', 'config/secrets.yml', 'config/memcache_settings.yml',
                     'config/unicorn.rb', '.env'
                 ]


# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .rbenv-version to your repository.
  # invoke :'rbenv:load'

  set :rails_env, ENV['on'].to_sym unless ENV['on'].nil?
  # For those using RVM, use this to load an RVM version@gemset.
  require "#{File.join(__dir__, 'deploy', "#{rails_env}_configuration_files", 'settings')}"
  invoke :"rvm:use[ruby-#{ruby_version}@#{gemset}]"
end


#this is the task to call from setup. 

# DON't RUN THIS TASK, IT WILL RUN FROM SETUP
task :setup_prerequesties => :environment do
  queue! %[sudo -A apt-get install mysql-server git-core libmysqlclient-dev nodejs memcached nginx]
  queue! %[mkdir "#{deploy_to}"]
  queue! %[chown -R "#{user}" "#{deploy_to}"]
  queue! %[curl -sSL https://get.rvm.io | bash -s stable --ruby]
  queue! %[source "#{rvm_path}"]
  queue! %[rvm requirements]
  queue! %[rvm install "#{ruby_version}"]

  #setup nginx
  queue! %[sudo -A su -c "echo '#{erb(File.join(__dir__, 'deploy', 'common_template', 'nginx_conf.erb'))}' > /etc/nginx/sites-enabled/#{application}"]
  queue! %[sudo -A rm -f /etc/nginx/sites-enabled/default]

  #set unicorn settings
  queue! %[echo "#{erb(File.join(__dir__, 'deploy', 'common_template','unicorn.erb'))}" > #{File.join(deploy_to, shared_path, '/config/unicorn.rb')}]

  #setup unicorn
  queue! %[echo '#{erb(File.join(__dir__, 'deploy','common_template', 'unicorn_init.erb'))}' > /tmp/unicorn_#{application}]
  queue! %[chmod +x /tmp/unicorn_#{application}]
  queue! %[sudo -A mv -f /tmp/unicorn_#{application} /etc/init.d/unicorn_#{application}]
  queue! %[sudo -A update-rc.d -f unicorn_#{application} defaults]

  queue! %[sudo -A service nginx restart]
end

task :setup_yml => :environment do
  Dir[File.join(__dir__, 'deploy', "#{rails_env.to_s}_configuration_files", '*.erb')].each do |_path|
    queue! %[echo "#{erb _path}" > "#{File.join(deploy_to, 'shared/config', File.basename(_path, '.erb') +'.yml')}"] unless ['sudo_password'].include?(File.basename(_path, '.erb'))
  end
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.

# RUN THIS TASK TO SETUP THE WORKER AND WEB MACHINE WITH COMMON PACKAGES AND CONFIGURATION FILES ALL YML AND SHARED DIRS
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

# RUN THIS to deploy to all webs
task :deploy_to_all_web => :environment do
  invoke :set_sudo_password
  queue! %[sudo -A service unicorn_#{application} stop]
  invoke :deploy
  queue! %[sudo -A service nginx restart]
  queue! %[sudo -A service unicorn_#{application} start]

end

desc "Deploys the current version to the server."
# DON'T RUN THIS TASK IT WILL RUN FROM deploy_to_all_worker or deploy_to_all_web
task :deploy => :environment do
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    #to :launch do
    #end
  end
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers

