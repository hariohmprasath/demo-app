export CONNECTION_NAME=reinvent-2023-connection

# 0-Cleanup
aws apprunner delete-connection --connection-arn $(aws apprunner list-connections --connection-name ${CONNECTION_NAME} | jq -r '.ConnectionSummaryList[0].ConnectionArn')

# 1-Create a new connection
CONNECTION_ARN=$(aws apprunner create-connection \
    --connection-name ${CONNECTION_NAME} \
    --provider-type GITHUB --output text \
    --query 'Connection.ConnectionArn')
echo "Connection ARN: ${CONNECTION_ARN}"

# 2-Create a new service
rm -Rf input.json && cat > input.json << EOF
{
  "ServiceName": "1-move-to-cloud",
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "ConnectionArn": "${CONNECTION_ARN}"
    },
    "AutoDeploymentsEnabled": true,
    "CodeRepository": {
      "RepositoryUrl": "https://github.com/hariohmprasath/demo-app",
      "SourceCodeVersion": {
        "Type": "BRANCH",
        "Value": "main"
      },
      "CodeConfiguration": {
        "ConfigurationSource": "API",
        "CodeConfigurationValues": {
          "Runtime": "CORRETTO_11",
          "BuildCommand": "mvn clean install -DskipTests=true",
          "StartCommand": "java -jar target/spring-petclinic-3.1.0-SNAPSHOT.jar",
          "Port": "8080"
        }
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "2 vCPU",
    "Memory": "4 GB"
  }
}
EOF

# 3-Print outputs
SERVICE_ARN=$(aws apprunner create-service --cli-input-json file://input.json \
 --output text \
 --query 'Service.ServiceArn')
echo "Service ARN: ${SERVICE_ARN}"

SERVICE_URL=$(aws apprunner describe-service --service-arn ${SERVICE_ARN} | jq -r '.Service.ServiceUrl')
echo "Service URL: ${SERVICE_URL}"
