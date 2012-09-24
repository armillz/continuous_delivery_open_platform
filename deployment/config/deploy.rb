require 'rubygems'
require 'aws-sdk'
load File.expand_path('/opt/aws/aws.config')

sdb = AWS::SimpleDB.new

def get_binding
  binding # So that everything can be used in templates generated for the servers
end

def from_template(file)
  require 'erb'
  template = File.read(File.join(File.dirname(__FILE__), "..", file))
  result = ERB.new(template).result(self.get_binding)
end

set :stack, ENV['stack']
set :ssh_key, ENV['key']
set :artifact, ENV['artifact']

set :artifact_bucket do
  item = sdb.domains["stacks"].items["#{stack}"]
  item.attributes['ArtifactBucket'].values[0].to_s.chomp
end

set :ip_address do
  item = sdb.domains["stacks"].items["#{stack}"]
  item.attributes['InstanceIPAddress'].values[0].to_s.chomp
end

set :user,             "ec2-user"
set :use_sudo,         false
set :deploy_to,        "/usr/share/tomcat6/webapps"
set :artifact_url,     "http://mirrors.jenkins-ci.org/war/1.480/jenkins.war"
set :ssh_options,      { :forward_agent => true, 
                         :paranoid => false, 
                         :keys => ssh_key }

set :application, domain

role :web, ip_address
role :app, ip_address
role :db,  ip_address, :primary => true

set :deploy_via, :remote_cache

namespace :deploy do
  
  task :setup do
    run "sudo chown -R tomcat:tomcat #{deploy_to}"
    run "sudo service httpd stop"
    run "sudo service tomcat6 stop"
    run "sudo rm -rf #{deploy_to}/*"
  end
  
  task :deploy do
    run "cd #{deploy_to} && sudo wget #{artifact_url}"
  end

  task :restart, :roles => :app do
    run "sudo service httpd restart"
    run "sudo service tomcat6 restart"
  end
  
  after "deploy:setup", "deploy:deploy"
  after "deploy:deploy", "deploy:restart"
end

