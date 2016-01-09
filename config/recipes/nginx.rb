namespace :nginx do

  desc "Setup nginx configuration for this application"
  task :setup => :environment do
    queue! %[sudo -A su -c "echo '#{erb(File.join(__dir__, 'templates', 'nginx_conf.erb'))}' > /etc/nginx/sites-enabled/#{application}"]
    queue! %[sudo -A rm -f /etc/nginx/sites-enabled/default]
  end

  %w[start stop restart].each do |command|
    desc "#{command} nginx"
    task command.to_sym => :environment do
      queue! %[sudo -A service nginx #{command}]
    end
  end
end