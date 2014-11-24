include_recipe 'deploy'
include_recipe 'docker'

node[:deploy].each do |application, deploy|

  if node[:opsworks][:instance][:layers].first != deploy[:environment_variables][:layer]
    Chef::Log.debug("Skipping deploy::docker application #{application} as it is not deployed to this layer")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  docker_registry '#{deploy[:environment_variables][:registry_url]}' do
    username '#{deploy[:environment_variables][:registry_username]}'
    password '#{deploy[:environment_variables][:registry_password]}'
  end

  # Pull tagged image
  docker_image '#{deploy[:environment_variables][:registry_image]}' do
    tag '#{deploy[:environment_variables][:registry_tag]}'
  end

  bash "docker-cleanup" do
    user "root"
    code <<-EOH
      if docker ps | grep #{deploy[:application]};
      then
        docker stop #{deploy[:application]}
        sleep 3
        docker rm -f #{deploy[:application]}
      fi
      docker rmi -f #{deploy[:environment_variables][:registry_image]}:#{deploy[:environment_variables][:registry_tag]}
    EOH
  end

  dockerenvs = " "
  deploy[:environment_variables].each do |key, value|
    dockerenvs=dockerenvs+" -e "+key+"="+value
  end

  bash "docker-run" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
      docker run #{dockerenvs} -p #{node[:opsworks][:instance][:private_ip]}:#{deploy[:environment_variables][:service_port]}:#{deploy[:environment_variables][:container_port]} --name #{deploy[:application]} -d grep #{deploy[:environment_variables][:registry_image]}:#{deploy[:environment_variables][:registry_tag]}
    EOH
  end

end
