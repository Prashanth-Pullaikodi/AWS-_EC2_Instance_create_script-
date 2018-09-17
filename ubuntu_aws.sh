export DEBIAN_FRONTEND=noninteractive
sudo /usr/bin/env DEBIAN_FRONTEND=noninteractive
echo -e " Connected to Instance ........\n"
echo -e "Please wait... Running  Update  ........\n"
sudo apt-get update
echo -e "Configuring Docker Repo on `hostname`  ........\n"
sudo apt-get -y install curl
sudo curl -fsSL https://get.docker.com/ | sh
sudo service docker start
echo -e "Docker Service Started...\n"
sudo docker run -p 80:80 -d nginx
echo -e "Starting Nginx .......\n"
exit

