namespace :unicorn do
  desc "Setup Unicorn initializer and app configuration"
  task :setup => :environment do
    queue! %[echo "#{erb(File.join(__dir__, 'templates', 'unicorn.erb'))}" > #{File.join(deploy_to, shared_path, '/config/unicorn.rb')}]
    queue! %[echo '#{erb(File.join(__dir__, 'templates', 'unicorn_init.erb'))}' > /tmp/unicorn_#{application}]
    queue! %[chmod +x /tmp/unicorn_#{application}]
    queue! %[sudo -A mv -f /tmp/unicorn_#{application} /etc/init.d/unicorn_#{application}]
    queue! %[sudo -A update-rc.d -f unicorn_#{application} defaults]
  end

  %w[start stop restart status].each do |command|
    desc "EXECUTING #{command} UNICORN"
    task command.to_sym => :environment do
      queue! %[ echo running #{command} unicorn]
      queue! "sudo -A service unicorn_#{application} #{command}"
    end
  end
end