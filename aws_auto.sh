################
#!/bin/bash
################
#
# 	Author: Prashanth Pullaikodi
# 	Purpose : Script to Automate AWS instance creation and deploy NGINX docker Image with Default Web Page.
# 	Pre-Requisites : The script requires pre-configured AWS cli with your key/Pair.
# 	Date: 11-27-2016
# 	Script Version : V.1.0
#
################

#OutPut File
OutPut="/var/log/output.txt"
OutPut1="/var/log/output-erro.txt"

#Empty Log file.
truncate -s 0 $OutPut1
truncate -s 0 $OutPut

#Globalise the Command
export aws="/usr/bin/aws"
export DEBIAN_FRONTEND=noninteractive


#Error Handling Function
#0-stdin ,1-stdout,2-stderr 
#Error Message dirrected to output.txt and stdout to file output1.txt
exec 2>> $OutPut 2>1& >> ${OutPut1}

log()
	{
    		echo "[${USER}][`date`] - ${*}" >> ${OutPut}
	}

usage ()
{
  echo 'Usage : Script <Image ID> <cidr> '
  echo "   eg : ./`basename "$0"` "ami-875042eb" "10.0.0.0/24" "
  echo ' 	'
  echo '   Current Free tire Images.Choose Any one.Script Currently support only below Image deployment '
  echo '     1.Linux  - "ami-e4c63e8b" '
  echo '     2.Ubuntu - "ami-8504fdea" '
  echo '  '
  exit
}

#Check Argument .Exit if NOT = or Less than 1.

if [ "$#" -le 1 ]; then
  usage
fi

#Capture Argument value to varibale.

im_id=$1
cidr=$2



#Clear the Screen
printf "\033c" #clear screen
echo -e "\n"

#Capture Current Public IP to allow port 80 and 22
myIP=`/usr/bin/curl -s ifconfig.co`
echo -e "Your Public IP is $myIP \n "
echo -e "Starting AWS Instance Creation Script..........\n"

log "`date`"
log "#########################################################################################" 
#Below Command creates AWS key pari to connect your account.
#aws ec2 create-key-pair --key-name my-key --query 'KeyMaterial' --output text > ~/.ssh/my-key.pem
#chmod 400 ~/.ssh/my-key.pem

#Configure your Region for AWS cli,for this you need to download Access Key from AWS console.
#aws configure


#Test AWS CLi Connectivity.
   $aws ec2  describe-regions > /dev/null 

if [ "$?" -eq "0" ];then
	log "AWS cli connection working ......" 
	echo "AWS cli connection working ......"
  else  
	log "AWS Cli connection issue.Unable to contact AWS.Check connectvity and configurtaion..." 
	echo  "AWS Cli connection issue.Unable to contact AWS.Check connectvity and configurtaion..." 
fi


#Check VPC already created for CIDR value .If not create new one.

$aws ec2 describe-vpcs  --filters  |grep $cidr > /dev/null

if [ "$?" -ne "0" ];then

	 vpc_id=$($aws ec2 create-vpc --cidr-block $cidr  --query 'Vpc.VpcId' --output text) 
	 log "$vpc_id" 
	 echo -e "Created VPC ... $vpc_id \n"


	#Modify the Dns-Support and DNS-hostname to assign public DNS names.

	 $aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-support "{\"Value\":true}" > /dev/null
	 $aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-hostnames "{\"Value\":true}" >/dev/null


	#Create Subnets.

	 sub_id=$($aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $cidr --query 'Subnet.SubnetId' --output text)
	 log "$sub_id"
	 echo -e "Created Subnet ... $sub_id \n"

	#Create InernetGateway
	 ig_id=$($aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
	 log "$ig_id"
	 echo -e "Created InternetGateway ... $ig_id \n"

	 #Attach IG
	 $aws ec2 attach-internet-gateway --internet-gateway-id $ig_id --vpc-id $vpc_id > /dev/null


	#Add a route table to the  subnet that allows traffic ,routed to the internet through our earlier created internet gateway.
	 rt_id=$($aws ec2 create-route-table --vpc-id $vpc_id --query 'RouteTable.RouteTableId' --output text)
	 log "$rt_id"
	 echo -e "Created RoutingTable ... $rt_id \n"


	 $aws ec2 associate-route-table --route-table-id $rt_id --subnet-id $sub_id > /dev/null 
	 $aws ec2 create-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id $ig_id > /dev/null

	#Add security Groupt to allow Traffic- here i allowed --cidr 0.0.0.0/0,since i dont know the Ip when i connect to internet.

	 sg_id=$($aws ec2 create-security-group --group-name mysgp --description "SSH adn Web access" --vpc-id $vpc_id --query 'GroupId' --output text)
	 log "$sg_id"
	 echo -e  "Created SecurityGroup... $sg_id \n"

	#Allow Port 22,80 and 443 

	for port in 22 80 443 
	   do
	
		 echo -e "Modifying FW rule for port $port.....\n"
		 $aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port $port --cidr $myIP/16
	  done

    	 #aws ec2 describe-images --filters --query 'Images[*].{ID:ImageId}
	 #Create new Instance 
	 #List AMI owner ID's " aws ec2 describe-images --owners 309956199498 |grep "ImageId"|grep ami-875042eb"
	 #ami-26c43149 - ubuntu , linux = ami-875042eb

	 log "##############################################################################"
	 log "Creating Intance............"


	 in_id=$($aws ec2 run-instances --image-id $im_id  --count 1 --instance-type t2.micro --key-name MyKeyPair --security-group-ids $sg_id --subnet-id $sub_id --associate-public-ip-address --query 'Instances[0].InstanceId' --output text)
	 log "$in_id"
	 echo -e "Created Instance ... $in_id \n"

	#Capture DNS name for the host

 	 in_name=$($aws ec2 describe-instances --instance-ids $in_id --query 'Reservations[0].Instances[0].PublicDnsName' --output text)
         log "$in_name"
         echo -e "Public DNS name for Instance ... $in_name \n"


	#Wait for few secods to create the node .Chek if instance is up and running"
	#$aws ec2 describe-instances --instance-ids $in_id --query 'Reservations[*].Instances[*].[State.Name, InstanceId]' --output text |grep -i running > /dev/null


         echo -n "Instance Not ready yet ...Please wait."
         until /usr/bin/nc -vzw 2 $in_name 22  2> /dev/null
                do
                        log "Waiting for Instance ready ....."
                        for X in {1..10}; do echo -n  .; sleep 0.1; done
                        #sleep 170
                done



else

	 log "VPC already created for '10.0.0.0/24' ......"
	 sg_id=$($aws ec2 describe-security-groups  --filters Name=group-name,Values='mysgp' --query 'SecurityGroups[*].{ID:GroupId}'  --output text)
   	 log "Security Group ID .. $sg_id"
	 echo -e "Security Group ID .. $sg_id \n"
   
	 vpc_id=$($aws ec2 describe-vpcs  --filters --output text |grep $cidr |awk '{print $7}')
   	 log "VPC ID ...$vpc_id"
   	 echo -e  "VPC ID ...$vpc_id\n"

  	 sub_id=$($aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock}' --output text|awk '{print $2}')
         log "Subnet ID .. $sub_id"
         echo -e  "Subnet ID .. $sub_id \n"

         in_id=$($aws ec2 run-instances --image-id $im_id  --count 1 --instance-type t2.micro --key-name MyKeyPair --security-group-ids $sg_id --subnet-id $sub_id --associate-public-ip-address --query 'Instances[0].InstanceId' --output text)
         log "$in_id"
         echo -e "Created Instance ... $in_id \n"



	#Capture DNS name for the host
	 in_name=$($aws ec2 describe-instances --instance-ids $in_id --query 'Reservations[0].Instances[0].PublicDnsName' --output text)
	 log "$in_name"
	 echo -e  "Public DNS name for Instance ... $in_name \n"


	#Wait for few secods to create the node
	#Chek if instance is up and running"
	#$aws ec2 describe-instances --instance-ids $in_id --query 'Reservations[*].Instances[*].[State.Name, InstanceId]' --output text |grep -i running > /dev/null

	
	 echo -n "Instance Not ready yet ...Please wait."
	 until /usr/bin/nc -vzw 2 $in_name 22  2> /dev/null
		do
			log "Waiting for Instance ready ....." 
			for X in {1..10}; do echo -n  .; sleep 0.1; done
			#sleep 170
		done

fi


	#Login to the Running instance 
	#ssh -i $1 ec2-user@$in_name - Use argument intake ,if  you dont want to hard key file path


echo  -e "Connecting to Instance ,installing and configuring  Docker,Nginx.....Please wait,it takes 4-5 minutes to complete .... \n"
log "Connecting to Instance ,installing and configuring  Docker and Nginx.....Please wait,it takes 4-5 minutes to complete ...."


if [ "$im_id" = "ami-8504fdea" ];then
	RESULTS=`ssh -o StrictHostKeyChecking=no -q  -t  -i /root/MyKeyPair.pem ubuntu@$in_name  "bash -s" < ./ubuntu_aws.sh`
	echo  "${RESULTS}" 2>> log 1>&2 > ${OutPut1}

elif [ "$im_id" = "ami-e4c63e8b" ];then

        RESULTS=`ssh -o StrictHostKeyChecking=no -q   -i /root/MyKeyPair.pem ec2-user@$in_name  "bash -s" < ./rhel_aws.sh`
        echo  "${RESULTS}" 2>> log 1>&2 > ${OutPut1}

else
	echo "OS version unknown ..Exiting...."
	exit
fi


echo  -e "Installation Completed  ........\n"
	log  "Installation Completed  ........\n"
echo -e  "Your EC2 " $in_name " instance is ready  ........\n"
	log  "Your EC2 " $in_name " instance is ready  ........"

#Finaly Test the WebServer is running or not.

/usr/bin/curl  -s http://$in_name |grep nginx > /dev/null
        if [ $? = 0 ];then
                echo  -e "Web server Running Sucessfully .Access your WebPage using URL  http://$in_name  ........ \n"
			log "Access your WebPage using URL  http://$in_name  ........ "
        else
                echo -e "WebPage not available..Please check Docker Installation  ........ \n"
                	log "WebPage not available..Please check Docker Installation  ........ \n"
        fi


#END
