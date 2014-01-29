# Installs https://github.com/MeetMe/newrelic-plugin-agent
# Expects there to be psql in the path to configure newrelic_plugin_agent[postgresql] and dynamically get database names

# Configuration
config_directory = node['newrelic']['server_monitoring']['meetme_plugin']['config_dir']
user             = node['newrelic']['server_monitoring']['meetme_plugin']['user']

if(node['newrelic']['server_monitoring']['meetme_plugin']['database_names'].empty?)
  require 'chef/mixin/shell_out'
  database_name_cmd = shell_out!("psql -U postgres -c 'SELECT datname FROM pg_database WHERE datistemplate = false;' | head -n -2 | tail -n +3 | xargs")
  database_names = database_name_cmd.stdout.split(" ")
else
  database_names = ['postgres']
end

# Set up directories
directory config_directory do
  recursive true
  owner user
end

directory '/var/log/newrelic' do
  recursive true
  owner user
end

directory '/var/run/newrelic' do
  recursive true
  owner user
end

# Install PIP and our packages
package 'py27-pip' do
  action :install
end

python_pip "newrelic-plugin-agent" do
  action :install
end

python_pip "newrelic_plugin_agent[postgresql]" do
  action :install
end

config_file_path = "#{config_directory}newrelic_plugin_agent.cfg"

template config_file_path do
  source 'newrelic_plugin_agent.cfg.erb'
  variables(
    :license_key => node['newrelic']['server_monitoring']['license'],
    :database_names => database_names,
    :user => user
  )
  owner user
  notifies :restart, 'service[newrelic_plugin_agent]', :delayed
end

smf 'newrelic_plugin_agent' do
  start_command "/opt/local/bin/newrelic_plugin_agent -c #{config_file_path}"
  stop_command ":kill"
  start_timeout 10
  stop_timeout 10
  working_directory "/opt/local/etc/newrelic"
  user user
  notifies :start, 'service[newrelic_plugin_agent]', :delayed
end

service 'newrelic_plugin_agent' do
  supports :start => true, :stop => true, :restart => true
  action :nothing
end
