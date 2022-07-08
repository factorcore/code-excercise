pipeline {
	agent { docker { image 'maven:3.8.4-openjdk-18-slim' } }

	triggers {
		pollSCM 'H/10 * * * *'
	}

	options {
		disableConcurrentBuilds()
		buildDiscarder(logRotator(numToKeepStr: '14'))
	}

	stages {
		stage("Clone Source") {
			steps {
				git url: ''
			}
		}
				stage('Terraform Init') {
			steps {
				sh "cd tf/ && export TF_VAR_region='${env.aws_region}' && export TF_VAR_access_key='${env.access_key}' && export TF_VAR_secret_key='${env.secret_key}' && terraform init"
			}
		}
		        stage ('Terraform Plan'){
            steps {
                sh "cd tf/ && export TF_VAR_region='${env.aws_region}' && export TF_VAR_access_key='${env.access_key}' && export TF_VAR_secret_key='${env.secret_key}' && terraform plan" 
            }
        }
		stage ('Terraform Apply'){
            steps {
                sh "cd tf/ && export TF_VAR_region='${env.aws_region}' && export TF_VAR_access_key='${env.access_key}' && export TF_VAR_secret_key='${env.secret_key}' && terraform apply -auto-approve"
            }
        }
		stage('pack and ship') {
			steps {
				sh "mvn package"
				sh "mv target/*.jar ../" 
				step([$class: 'AWSCodeDeployPublisher', applicationName: '', awsAccessKey: '', awsSecretKey: '', credentials: 'awsAccessKey', deploymentGroupAppspec: false, deploymentGroupName: '', deploymentMethod: 'deploy', excludes: 'Jenkinsfile,mvnw, pom.xml, src/, target/, tf/', iamRoleArn: '', includes: '**', proxyHost: '', proxyPort: 0, region: 'us-east-2', s3bucket: 'api-releases', s3prefix: '', subdirectory: '', versionFileName: '', waitForCompletion: false])
			}
		}
    

	}

	post {
		changed {
			script {
				slackSend(
						color: (currentBuild.currentResult == 'SUCCESS') ? 'good' : 'danger',
						channel: '#sagan-content',
						message: "${currentBuild.fullDisplayName} - `${currentBuild.currentResult}`\n${env.BUILD_URL}")
				emailext(
						subject: "[${currentBuild.fullDisplayName}] ${currentBuild.currentResult}",
						mimeType: 'text/html',
						recipientProviders: [[$class: 'CulpritsRecipientProvider'], [$class: 'RequesterRecipientProvider']],
						body: "<a href=\"${env.BUILD_URL}\">${currentBuild.fullDisplayName} is reported as ${currentBuild.currentResult}</a>")
			}
		}
	}
}
