# to make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV["VAGRANT_NO_PARALLEL"] = "yes"

require "ipaddr"

number_of_server_nodes  = 1
number_of_client_nodes  = 2
first_server_node_ip    = "10.11.0.101"
first_client_node_ip    = "10.11.0.201"

server_node_ip_address  = IPAddr.new first_server_node_ip
client_node_ip_address  = IPAddr.new first_client_node_ip

Vagrant.configure(2) do |config|
  config.vm.box = "windows-2019-amd64"

  config.vm.provider "libvirt" do |lv, config|
    lv.memory = 3*1024
    lv.cpus = 2
    lv.cpu_mode = "host-passthrough"
    lv.nested = false
    lv.keymap = "pt"
    config.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: ENV["USER"], smb_password: ENV["VAGRANT_SMB_PASSWORD"]
  end

  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.cpus = 2
    vb.memory = 3*1024
    vb.customize ["modifyvm", :id, "--vram", 64]
    vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
  end

  (1..number_of_server_nodes).each do |n|
    name = "server#{n}"
    fqdn = "#{name}.example.test"
    ip_address = server_node_ip_address.to_s; server_node_ip_address = server_node_ip_address.succ

    config.vm.define name do |config|
      config.vm.hostname = name
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: "none", libvirt__dhcp_enabled: false
      config.vm.provision "hosts", :sync_hosts => true, :add_localhost_hostnames => false
      config.vm.provision "shell", path: "ps.ps1", args: "provision-choco.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: "provision-containers-feature.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: "provision.ps1", reboot: true
      config.vm.provision "shell", path: "ps.ps1", args: "provision-docker-ce.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: ["provision-consul-server.ps1", ip_address, first_server_node_ip, number_of_server_nodes]
      config.vm.provision "shell", path: "ps.ps1", args: ["provision-vault-server.ps1", ip_address, n == number_of_server_nodes && 'true' || 'false']
      config.vm.provision "shell", path: "ps.ps1", args: ["provision-nomad-server.ps1", ip_address, first_server_node_ip, number_of_server_nodes]
      config.vm.provision "shell", path: "ps.ps1", args: ["provision-prometheus.ps1", number_of_server_nodes, number_of_client_nodes] if n == 1
      config.vm.provision "shell", path: "ps.ps1", args: "provision-grafana.ps1" if n == 1
      config.vm.provision "shell", path: "ps.ps1", args: "provision-shortcuts.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: "provision-consul-server-summary.ps1" if n == number_of_server_nodes
      config.vm.provision "shell", path: "ps.ps1", args: "provision-nomad-server-summary.ps1" if n == number_of_server_nodes
      # configure the vault server auto-unseal in all nodes after the last one is up.
      if n == number_of_server_nodes
        config.trigger.after :up do |trigger|
          trigger.info = "Configuring Vault Server Auto Unseal..."
          trigger.ruby do |env, machine|
            env.active_machines.each do |machine_name, machine_provider|
              next unless machine_name =~ /^server/
              m = env.machine(machine_name, machine_provider)
              next unless m.state.id == :running
              m.ui.info "Configuring the Vault Server Auto Unseal..."
              system(
                'vagrant',
                'powershell',
                '--command',
                'C:/vagrant/ps.ps1 provision-vault-server-auto-unseal.ps1',
                '--elevated',
                machine_name.to_s
              )
            end
          end
        end
      end
    end
  end

  (1..number_of_client_nodes).each do |n|
    name = "client#{n}"
    fqdn = "#{name}.example.test"
    ip_address = client_node_ip_address.to_s; client_node_ip_address = client_node_ip_address.succ

    config.vm.define name do |config|
      config.vm.hostname = name
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: "none", libvirt__dhcp_enabled: false
      config.vm.provision "hosts", :sync_hosts => true, :add_localhost_hostnames => false
      config.vm.provision "shell", path: "ps.ps1", args: "provision-choco.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: "provision-containers-feature.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: "provision.ps1", reboot: true
      config.vm.provision "shell", path: "ps.ps1", args: "provision-docker-ce.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: ["provision-consul-client.ps1", ip_address, first_server_node_ip]
      config.vm.provision "shell", path: "ps.ps1", args: ["provision-nomad-client.ps1", ip_address, first_server_node_ip]
      config.vm.provision "shell", path: "ps.ps1", args: "provision-shortcuts.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: ["examples/consul-ad-hoc/run.ps1", ip_address]
      config.vm.provision "shell", path: "ps.ps1", args: "examples/graceful-stop/run.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: "examples/damon/run.ps1"
      config.vm.provision "shell", path: "ps.ps1", args: ["examples/go-info/run.ps1", n] if n <= 2
    end
  end
end
