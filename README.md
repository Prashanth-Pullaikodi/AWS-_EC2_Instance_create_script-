
Shell script to create EC2 Instance using AWS CLI

Pre-Requsite : 

       Make sure AWS cli (Script tested only on LInux)has been setup on your local machine ,before running this script.
 For more infromation ,please reffer https://docs.aws.amazon.com/cli/latest/userguide/installing.html
 
 Script is designed to install Ubuntu/rhel .Incase if you need any other OS ,create your on OS.sh script.
 
 Execution:
 
 First Clone this repo to your local machine  and run the script with ami ID as an argument.
 
 Usage: 
 
 Usage:   Script <Image ID> <cidr> '
         eg : ./`basename "$0"` "ami-875042eb" "10.0.0.0/24" "


        
