#
# Cookbook Name:: awesome_customers_windows
# Recipe:: database
#
# Copyright (c) 2016 The Authors, All Rights Reserved.
# Load the secrets file and the encrypted data bag item that holds the sa password.
password_secret = Chef::EncryptedDataBagItem.load_secret(node['awesome_customers_windows']['secret_file'])
password_data_bag_item = Chef::EncryptedDataBagItem.load('database_passwords', 'sql_server_customers', password_secret)

# Set the node attribute that holds the sa password with the decrypted passoword.
node.default['sql_server']['server_sa_password'] = password_data_bag_item['sa_password']

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

# Run the SQL file only if the 'learnchef' database has not yet been created.
powershell_script 'Initialize database' do
  code <<-EOH
    Import-Module "#{sqlps_module_path}"
    Invoke-Sqlcmd -InputFile #{create_database_script_path}
  EOH
  guard_interpreter :powershell_script
  only_if <<-EOH
    Import-Module "#{sqlps_module_path}"
    (Invoke-Sqlcmd -Query "SELECT COUNT(*) AS Count FROM sys.databases WHERE name = 'learnchef'").Count -eq 0
  EOH
end

# Create a path to the SQL file in the Chef cache.
grant_access_script_path = win_friendly_path(File.join(Chef::Config[:file_cache_path], 'grant-access.sql'))

# Copy the SQL file from the cookbook to the Chef cache.
cookbook_file grant_access_script_path do
  source 'grant-access.sql'
end

# Run the SQL file only if IIS APPPOOL\Products does not have access.
powershell_script 'Grant SQL access to IIS APPPOOL\Products' do
  code <<-EOH
    Import-Module "#{sqlps_module_path}"
    Invoke-Sqlcmd -InputFile #{grant_access_script_path}
  EOH
  guard_interpreter :powershell_script
  not_if <<-EOH
    Import-Module "#{sqlps_module_path}"
    $sp = Invoke-Sqlcmd -Database learnchef -Query "EXEC sp_helprotect @username = 'IIS APPPOOL\\Products', @name = 'customers'"
    ($sp.ProtectType.Trim() -eq 'Grant') -and ($sp.Action.Trim() -eq 'Select')
  EOH
end
