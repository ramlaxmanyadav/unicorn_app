set :branch, ENV['BRANCH'] || 'master'

set :domain, ENV['DOMAIN'] || '54.201.93.50'

set :user, 'deploy'

set :unicorn_worker_count, 4

set :ssl_enabled, false

task :set_sudo_password => :environment do
  queue! "echo '#{erb(File.join(__dir__,'sudo_password.erb'))}' > /home/deploy/SudoPass.sh"
  queue! "chmod +x /home/deploy/SudoPass.sh"
  queue! "export SUDO_ASKPASS=/home/deploy/SudoPass.sh"
end
