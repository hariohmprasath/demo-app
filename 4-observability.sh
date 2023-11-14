cat > observability.json << EOF
{
  "ServiceArn": "${SERVICE_ARN}",
  "NetworkConfiguration": {
    "EgressConfiguration": {
      "EgressType": "VPC",
      "VpcConnectorArn": "${VPC_CONNECTOR_ARN}"
    }
  }
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "ConnectionArn": "${CONNECTION_ARN}"
    },
    "AutoDeploymentsEnabled": true,
    "CodeRepository": {
      "RepositoryUrl": "https://github.com/my-account/python-hello",
      "SourceCodeVersion": {
        "Type": "BRANCH",
        "Value": "main"
      },
      "CodeConfiguration": {
        "ConfigurationSource": "API",
        "CodeConfigurationValues": {
          "Runtime": "CORRETTO_11",
          "BuildCommand": "mvn clean install -DskipTests=true",
          "StartCommand": "java -Dspring.profiles.active=mysql -jar target/spring-petclinic-3.1.0-SNAPSHOT.jar",
          "Port": "8080"
        }
      }
    }
  }
}
EOF

aws apprunner update-service --cli-input-json file://update.json
