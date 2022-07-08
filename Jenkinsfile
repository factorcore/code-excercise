pipeline {
	agent { docker { image 'maven:3.8.6-openjdk-18' } }

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
				git url: 'https://github.com/factorcore/code-excercise.git'
			}
		}
		stage('pack and ship') {
			environment {
				AWS_ACCESS_KEY_ID     = credentials('jenkins-aws-secret-key-id')
				AWS_SECRET_ACCESS_KEY = credentials('jenkins-aws-secret-access-key')
   			 }
			steps {
				sh "mvn package"
				sh "mv target/*.jar ../" 
				step([$class: 'AWSCodeDeployPublisher', applicationName: 'API', awsAccessKey: $AWS_ACCESS_KEY_ID, awsSecretKey: $AWS_SECRET_ACCESS_KEY, credentials: 'awsAccessKey', deploymentGroupAppspec: false, deploymentGroupName: 'example-group', deploymentMethod: 'deploy', excludes: 'Jenkinsfile,mvnw, pom.xml, src/, target/, tf/', iamRoleArn: $ROLEARN, includes: '**', proxyHost: '', proxyPort: 0, region: 'us-east-2', s3bucket: $RELEASEBUCKET, s3prefix: '', subdirectory: '', versionFileName: $versionFileName, waitForCompletion: true])
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
