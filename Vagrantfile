Vagrant.configure(2) do |config|
    #prompt pour le user est qu'il soiet d'avoir ingress or d'installer wordpress ou est que veut d'avoir un nom de domaine
    ingressNginx = ""
	wordpress = ""
    #DNS
	wordpressUrl = ""
    #cree un prompt avec ruby que l'on veut s'execute lorsque on faire vagrant up ou vagrant provision up et provision se sont des argument
    case ARGV[0]
    when "provision", "up"

    print "Do you want nginx as ingress controller (y/n) ?\n"
    #stdin recupere et injecte dans le var
    ingressNginx = STDIN.gets.chomp
    print "\n"
        #si oui
        if ingressNginx == "y"
            #on veut demande d'installe wp oui ou non
            print "Do you want a wordpress in your kubernetes cluster (y/n) ?\n"
            wordpress = STDIN.gets.chomp
            print "\n"
            # si oui wordpress
            if wordpress == "y"
               #est ce qu'il soyet de definir l'url 
               print "Which url for your wordpress ?"
               wordpressUrl = STDIN.gets.chomp
               #unless si le user ne definir pas l'url on donne la valeurpar defaut wordpress.kub
               unless wordpressUrl.empty? then wordpressUrl else 'wordpress.kub' end
            end
        end
    else
    # do nothing
    end

    #on va definir var qui contient un script de shell de maniere explicite commune pour tout les machines presque
    common = <<-SHELL
    sudo apt update -qq 2>&1 >/dev/null
    sudo apt install -y -qq git vim tree net-tools telnet git python3-pip sshpass nfs-common 2>&1 >/dev/null
    curl -fsSL https://get.docker.com -o get-docker.sh 2>&1
    sudo sh get-docker.sh 2>&1 >/dev/null
    sudo usermod -aG docker vagrant
    sudo service docker start
    sudo echo "autocmd filetype yaml setlocal ai ts=2 sw=2 et" > /home/vagrant/.vimrc
    sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    SHELL

  

    #elt etchost initiallement vide =>variabe ruby
    etcHosts = ""

    #applique une image vagrant sur les deffirents nodes
	config.vm.box = "ubuntu/bionic64"
	config.vm.box_url = "ubuntu/bionic64"
	# list de dectionnaire
	NODES = [
  	{ :hostname => "autohaprox", :ip => "192.168.56.10", :cpus => 1, :mem => 512, :type => "haproxy" },
  	{ :hostname => "autokmaster", :ip => "192.168.56.11", :cpus => 4, :mem => 4096, :type => "kub" },
  	{ :hostname => "autoknode1", :ip => "192.168.56.12", :cpus => 2, :mem => 2048, :type => "kub" },
  	{ :hostname => "autoknode2", :ip => "192.168.56.13", :cpus => 2, :mem => 2048, :type => "kub" },
  	{ :hostname => "autodep", :ip => "192.168.56.20", :cpus => 1, :mem => 512, :type => "deploy" }
	]
    	# parocouris list node
    NODES.each do |node|
     #on verifie le type de box 
     if node[:type] != "haproxy"
    	etcHosts += "echo '" + node[:ip] + "   " + node[:hostname] + "' >> /etc/hosts" + "\n"
	 else
		etcHosts += "echo '" + node[:ip] + "   " + node[:hostname] + " autoelb.kub ' >> /etc/hosts" + "\n"
	 end
    end #end NODES


	# parocouris list node et cree ses node dans virtualbox
    NODES.each do |node|
     config.vm.define node[:hostname] do |cfg|
	   cfg.vm.hostname = node[:hostname]
       cfg.vm.network "private_network", ip: node[:ip]
       cfg.vm.provider "virtualbox" do |v|
		v.customize [ "modifyvm", :id, "--cpus", node[:cpus] ]
        v.customize [ "modifyvm", :id, "--memory", node[:mem] ]
        v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        v.customize ["modifyvm", :id, "--name", node[:hostname] ]
       end #end provider	
		#for all
        #elt de provisionning shell on va cree script etchosts pour ajoute tout les nodes a l'etc/hosts de nos machines
       cfg.vm.provision :shell, :inline => etcHosts
       #on besoin installation specifique pour HAproxy 
       if node[:type] == "haproxy"
        cfg.vm.provision :shell, :path => "install_haproxy.sh"
       end

       # for all servers in cluster (need docker)
       if node[:type] == "kub"
        cfg.vm.provision :shell, :inline => common
       end

       # for the deploy server
       if node[:type] == "deploy"
        cfg.vm.provision :shell, :inline => common
        #install un script specifique
        cfg.vm.provision :shell, :path => "install_kubespray.sh", :args => ingressNginx
        #si oui il va install wp donc on va install NFS & wp
        if wordpress == "y"
        #scripts specifiques
         cfg.vm.provision :shell, :path => "install_nfs.sh"
         cfg.vm.provision :shell, :path => "install_wordpress.sh", :args => wordpressUrl
        end
       end
     end # end config
    end # end nodes
end 

