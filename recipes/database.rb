#
# Cookbook Name:: awesome_customers_windows
# Recipe:: database
#
# Copyright (c) 2016 The Authors, All Rights Reserved.
# Install SQL Server.
include_recipe 'sql_server::server'

# Create a path to the SQL file in the Chef cache.
create_database_script_path = win_friendly_path(File.join(Chef::Config[:file_cache_path], 'create-database.sql'))

# Copy the SQL file from the cookbook to the Chef cache.
cookbook_file create_database_script_path do
  source 'create-database.sql'
end

# Get the full path to the SQLPS module.
sqlps_module_path = ::File.join(ENV['programfiles(x86)'], 'Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS')

# Run the SQL file only if the 'my_company' database has not yet been created.
powershell_script 'Initialize database' do
  code <<-EOH
    Import-Module "#{sqlps_module_path}"
    Invoke-Sqlcmd -InputFile #{create_database_script_path}
  EOH
  guard_interpreter :powershell_script
  only_if <<-EOH
    Import-Module "#{sqlps_module_path}"
    (Invoke-Sqlcmd -Query "SELECT COUNT(*) AS Count FROM sys.databases WHERE name = 'my_company'").Count -eq 0
  EOH
end
