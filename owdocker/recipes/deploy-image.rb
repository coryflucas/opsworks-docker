include_recipe 'docker'
include_recipe 'apt'
package 'apt-transport-https'

deploy = node
image = "#{deploy[:environment_variables][:registry_image]}"

if deploy[:environment_variables][:registry_username]
  docker_registry "#{deploy[:environment_variables][:registry_url]}" do
    username deploy[:environment_variables][:registry_username]
    password deploy[:environment_variables][:registry_password]
    email deploy[:environment_variables][:registry_username]
  end
end

docker_image "#{deploy[:environment_variables][:registry_image]}" do
  tag deploy[:environment_variables][:registry_tag]
end

docker_container "#{deploy[:environment_variables][:registry_image]}" do
  detach true
  hostname "#{node[:opsworks][:stack][:name]}-#{node[:opsworks][:instance][:hostname]}"
  env deploy[:environment_variables].map { |k,v| "#{k}=#{v}" if !k.match(/registry_password/)}.compact
  container_name deploy[:application]
  if deploy[:environment_variables][:ports]
    port deploy[:environment_variables][:ports].split(";")
  end
  if deploy[:environment_variables][:links]
    link deploy[:environment_variables][:links]
  end
  action :redeploy
end
