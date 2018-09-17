

 echo -e " Connected to Instance ........ \n"  
 sudo yum  -y update 
 echo -e "Please wait... Running Yum Update  ........ \n" 
 echo -e "Configuring Docker Repo on `hostname`  ........\n"
 sudo yum -y install curl
 sudo curl -fsSL https://get.docker.com/ | sh 
 sudo /bin/systemctl start  docker.service 
 echo -e "Docker Service Started...\n" 
 sudo docker run -p 80:80 -d nginx 
 echo -e "Starting Nginx .......\n" 

