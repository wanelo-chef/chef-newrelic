railsware_plugins_path = "/opt/newrelic/plugins/railsware"
newrelic_logwatcher_path = "#{railsware_plugins_path}/newrelic_logwatcher_agent"
owner = "nobody"

ruby_environment = {
  'LANG' => "en_us.UTF-8",
  'LC_LANG' => 'en_us.UTF-8',
  'BUNDLE_GEMFILE' => "#{newrelic_logwatcher_path}/Gemfile",
  'PATH' => '/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin'
}

watched_logs = node['newrelic']['logwatcher']['watched_logs']

# Log watcher specific setup
if watched_logs.any? && node['newrelic']['logwatcher']['enabled']
  directory "/opt/newrelic/plugins" do
    recursive true
    user owner
  end

  # Clone the railsware plugins into place
  git railsware_plugins_path do
    repository "https://github.com/railsware/newrelic_platform_plugins.git"
    reference "8edd6d214e462b27fdd07d41712eb7b4fff2f7d8"
    action :checkout
    user owner
  end

  execute "gem install bundler" do
    cwd newrelic_logwatcher_path
    environment ruby_environment
    not_if "gem list | grep bundler"
  end

  execute "bundle install" do
    cwd newrelic_logwatcher_path
    environment ruby_environment
  end

  template "#{newrelic_logwatcher_path}/config/newrelic_plugin.yml" do
    source "logwatcher-config.yml.erb"
    owner owner
    mode 0644
    variables(
      :license => node['newrelic']['server_monitoring']['license'],
      :log_files => watched_logs,
    )
    notifies :restart, "service[logwatcher]"
  end

  smf 'logwatcher' do
    start_command "bundle exec ruby #{newrelic_logwatcher_path}/newrelic_logwatcher_agent.rb &"
    start_timeout 10
    stop_timeout 10
    working_directory newrelic_logwatcher_path
    user owner
    environment(ruby_environment)
    notifies :start, 'service[logwatcher]', :delayed
  end

  service 'logwatcher' do
    supports :start => true, :stop => true, :restart => true
    action :nothing
  end
end

