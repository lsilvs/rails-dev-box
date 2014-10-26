# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure('2') do |config|

  config.vm.box      = 'dummy'
  config.vm.box_url  = 'https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box'

  config.vm.synced_folder "./APP_FOLDER", "/myapp", id: "vagrant-root"

  config.vm.provider :aws do |aws,override|
    
    aws.keypair_name = "KEYPAIR_NAME"
    aws.access_key_id = "ACCESS_KEY_ID"
    aws.secret_access_key = "SECRET_ACCESS_KEY"

    override.ssh.private_key_path  = "private_key.pem"

    aws.instance_type = "t1.micro"
    aws.ami = 'ami-013f9768'
    
    override.ssh.username = "ubuntu"
    
    aws.tags = {
        'Name' => 'MY_APP',
        'deployed_by' => 'deployer'
      }
  end

  config.vm.provision "shell", path: "utils/install_puppet.bash"

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = 'puppet/manifests'
    puppet.module_path    = 'puppet/modules'
  end
end
