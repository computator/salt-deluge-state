Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provider "virtualbox" do |v|
    v.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
  end

  config.vm.synced_folder ".", "/srv/salt/deluge"
  config.vm.synced_folder ".test_pillar", "/srv/pillar"
  config.vm.synced_folder "_modules", "/srv/salt/_modules"
  config.vm.synced_folder "_states", "/srv/salt/_states"

  config.vm.provision "salt"
  config.vm.provision "salt-local", type: "shell", inline: "sed -ri '/^#?file_client:/ c file_client: local' /etc/salt/minion"
  config.vm.provision "highstate", type: "shell", keep_color: true, inline: "salt-call --force-color state.apply deluge --state-output changes"
end
