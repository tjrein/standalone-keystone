#!/bin/env ruby

Vagrant.configure("2") do |config|
  config.ssh.forward_agent = true
  config.vm.box = 'newton_ubuntu_xenial'
  config.vm.box_url = 'https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-vagrant.box'

  config.vm.define "controller" do |controller|
    controller.vm.hostname = "controller"
 
    controller.vm.provision :shell, :path => "setup.sh"
    controller.vm.provision :shell, :path => "install_puppet_modules.sh"

    controller.vm.provision "puppet" do |puppet|
        puppet.options = "--verbose --debug"
        puppet.manifests_path = "puppet/manifests"
       puppet.manifest_file = "site.pp"
    end

    controller.vm.network "private_network", ip: "192.168.56.105"
    controller.vm.network "public_network", bridge: "en0: Wi-Fi (AirPort)"

    controller.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "4096"
    end

    
  end
end
