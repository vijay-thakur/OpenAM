#
# Cookbook Name:: openam
# Recipe:: default
#
# Copyright 2016, SourceFuse Technologies Pvt. Ltd.
#
# All rights reserved - Do Not Redistribute
#

isupgrade = true

if Dir.exist?('/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.101.x86_64')
  isupgrade = false
end

yum_package 'java-1.7.0-openjdk-devel' do
  action :install
end

bash 'Install Java7' do
	code <<-EOH
      set -e
      sudo alternatives --install /usr/bin/java java /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.101.x86_64/bin/java 100
      sudo alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.101.x86_64/bin/javac 100
      sudo alternatives --install /usr/bin/jar jar /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.101.x86_64/bin/jar 100
      sudo alternatives --set jar /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.101.x86_64/bin/jar
      sudo alternatives --set javac /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.101.x86_64/bin/javac
      sudo alternatives --set java /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.101.x86_64/bin/java
      EOH
  only_if { isupgrade == true }
end

template "/etc/profile.d/java_env.sh" do
  source "java_env.sh.erb"
  mode "0755"
end

group node['tomcat']['group'] do
  action 'create'
end

user node['tomcat']['user'] do
  gid node['tomcat']['group']
  shell '/bin/nologin'
  system true
  action 'create'
end

remote_file Chef::Config['file_cache_path'] + "/apache-tomcat-#{node['tomcat']['version']}.tar.gz" do
  source "http://redrockdigimark.com/apachemirror/tomcat/tomcat-#{node['tomcat']['buildnumber']}/v#{node['tomcat']['version']}/bin/apache-tomcat-#{node['tomcat']['version']}.tar.gz"
end

execute 'unzip tomcat' do
  cwd node['tomcat']['extract_path']
  command <<-EOF
            set -e
            cp -rf "#{Chef::Config['file_cache_path']}/apache-tomcat-#{node['tomcat']['version']}.tar.gz" /opt
            tar zxf "apache-tomcat-#{node['tomcat']['version']}.tar.gz"
            mv "apache-tomcat-#{node['tomcat']['version']}" tomcat7
            rm -rf "apache-tomcat-#{node['tomcat']['version']}.tar.gz"
        EOF
  only_if { isupgrade == true }
end


template '/etc/init.d/tomcat' do
  source node['tomcat']['init_daemon']
  mode '0755'
end

template "/etc/profile.d/tomcat_env.sh" do
  source "tomcat_env.sh.erb"
  mode "0755"
end


directory node['tomcat']['path'] do
  owner node['tomcat']['user']
  group node['tomcat']['group']
  recursive true
  mode "0755"
end

execute 'tomcat' do
  command <<-EOF
            set -e
            source /etc/profile.d/java_env.sh
            source /etc/profile.d/tomcat_env.sh
            chown -R tomcat:tomcat /opt/tomcat7
            chmod 775 /opt/tomcat7/webapps
        EOF
        notifies :reload, 'service[tomcat]'
  only_if { isupgrade == true }
end

service "tomcat" do
  service_name 'tomcat'
  supports :restart => true, :status => true, :reload => true
  action [:enable, :restart]
end
