1-	Create a hello world Java Springboot application using any reference code from public domain.
2-	Create a terraform template to deploy the API service under an ALB. Modules: EC2,ALB, Target Group. Assume that you are deploying in default VPC.
3-	Create AWS Codedeploy template with hooks for deploying dependencies, deploying the application, service stop/start and service validation
4-	Jenkins groovy script for code checkout from github/bitbucket: springboot application, codedeploy template, terraform template, and build & deploy by copying the code deploy template with build artifacts to S3
5-	(Good to have) Boto3 script to enable auto-scaling of the API service by using codedeploy integration with autoscaling group
6-	(Optional) Actual build and deployment using Jenkins instance