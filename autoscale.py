#!/usr/bin/python
import boto3

# Let's use Amazon S3
s3 = boto3.resource('s3')
cd_client = boto3.client('codedeploy')
response = cd_client.create_application(
   applicationName="API",
   computePlatform='EC2'
)
response = cd_client.create_deployment_group(
   applicationName='AppECS-sample-springboot-app-qa-bg',
   deploymentGroupName='DgpECS-sample-springboot-app-qa-bg',
   deploymentConfigName='CodeDeployDefault.ECSAllAtOnce',
   serviceRoleArn='arn:aws:iam::123456789123:role/ecs_service_role',
   triggerConfigurations=[
       {
           'triggerName': 'sample-springboot-app-qa-code-deploy-bg-trigger',
           'triggerTargetArn': 'arn:aws:sns:us-east-1:123456789123:my_sns_topic',
           'triggerEvents': [
               "DeploymentStart",
               "DeploymentSuccess",
               "DeploymentFailure",
               "DeploymentStop",
               "DeploymentRollback",
               "DeploymentReady"
           ]
       },
   ],
   autoRollbackConfiguration={
       'enabled': True,
       'events': [
           'DEPLOYMENT_FAILURE', 'DEPLOYMENT_STOP_ON_ALARM', 'DEPLOYMENT_STOP_ON_REQUEST',
       ]
   },
   deploymentStyle={
       'deploymentType': 'BLUE_GREEN',
       'deploymentOption': 'WITH_TRAFFIC_CONTROL'
   },
   blueGreenDeploymentConfiguration={
       'terminateBlueInstancesOnDeploymentSuccess': {
           'action': 'TERMINATE',
           'terminationWaitTimeInMinutes': 15
       },
       'deploymentReadyOption': {
           'actionOnTimeout': 'CONTINUE_DEPLOYMENT'
       }
   },
   loadBalancerInfo={
       'targetGroupPairInfoList': [
           {
               'targetGroups': [
                   {
                       'name': 'sample-springboot-app-qa-tg1'
                   },
                   {
                       'name': 'sample-springboot-app-qa-tg2'
                   }
               ],
               'prodTrafficRoute': {
                   'listenerArns': 'arn:aws:elasticloadbalancing:us-east-1:123456789123:listener/app/sample-springboot-app-qa-alb/2b8b8ab60f9c7e43/97b643f12d4fa8a4'
               },
               'testTrafficRoute': {
                   'listenerArns': 'arn:aws:elasticloadbalancing:us-east-1:123456789123:listener/app/sample-springboot-app-qa-alb/2b8b8ed64f9c7e43/09261df9b5476d39'
               }
           },
       ]
   },
)