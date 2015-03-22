include_recipe 'deploy'
include_recipe 'docker'

Chef::Log.info("Entering docker-image-deploy")

node[:deploy].each do |application, deploy|

  if node[:opsworks][:instance][:layers].first != deploy[:environment_variables][:layer]
    Chef::Log.warn("Skipping deploy::docker application #{application} as it is not deployed to this layer")
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

  Chef::Log.info('Docker cleanup')
  bash "docker-cleanup" do
    user "root"
    returns [0, 1]
    code <<-EOH
      if docker ps | grep #{deploy[:application]};
      then
        docker stop #{deploy[:application]}
        sleep 3
        docker rm -f #{deploy[:application]}
      fi
      if docker ps -a | grep #{deploy[:application]};
      then
        docker rm -f #{deploy[:application]}
      fi
      if docker images | grep #{deploy[:environment_variables][:registry_image]};
      then
        docker rmi -f $(docker images | grep -m 1 #{deploy[:environment_variables][:registry_image]} | awk {'print $3'})
      fi
    EOH
  end

  if deploy[:environment_variables][:registry_username]
    Chef::Log.info("REGISTRY: Login as #{deploy[:environment_variables][:registry_username]} to #{deploy[:environment_variables][:registry_url]}")
    docker_registry "#{deploy[:environment_variables][:registry_url]}" do
      username deploy[:environment_variables][:registry_username]
      password deploy[:environment_variables][:registry_password]
      email deploy[:environment_variables][:registry_email]
    end
  end

  # Pull tagged image
  Chef::Log.info("IMAGE: Pulling #{deploy[:environment_variables][:registry_image]}:#{deploy[:environment_variables][:registry_tag]}")
  docker_image "#{deploy[:environment_variables][:registry_image]}" do
    tag deploy[:environment_variables][:registry_tag]
  end

  dockerenvs = " "
  deploy[:environment_variables].each do |key, value|
    dockerenvs=dockerenvs+" -e "+key+"="+value unless key == "registry_password"
  end
  Chef::Log.info("ENVs: #{dockerenvs}")

  hostname = "#{node[:opsworks][:stack][:name]}-#{node[:opsworks][:instance][:hostname]}"
  Chef::Log.info("hostname: #{hostname}")

  volumes = ""
  if deploy[:environment_variables][:volumes]
    volumes = "-v #{deploy[:environment_variables][:volumes]}"
  end

  Chef::Log.info('docker-run start')
  bash "docker-run" do
    user "root"
    code <<-EOH
      docker run #{dockerenvs} -h #{hostname} -p #{node[:opsworks][:instance][:private_ip]}:#{deploy[:environment_variables][:service_port]}:#{deploy[:environment_variables][:container_port]} #{volumes} --name #{deploy[:application]} -d #{deploy[:environment_variables][:registry_image]}:#{deploy[:environment_variables][:registry_tag]}
    EOH
  end
  Chef::Log.info('docker-run stop')
end
Chef::Log.info("Exiting docker-image-deploy")
