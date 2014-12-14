include_recipe 'apt'
package 'apt-transport-https'

apt_repository "docker" do
  uri "https://get.docker.com/ubuntu"
  distribution "docker"
  components ["main"]
  keyserver "hkp://keyserver.ubuntu.com:80"
  key "36A1D7869245C8950F966E92D8576A8BA88D21E9"
  not_if { File.exists?("/etc/apt/sources.list.d/docker.list") }
end

# Install Docker latest version
package "docker" do
  package_name "lxc-docker"
  action :install
end

service "docker" do
  action :start
end
