# check CONNECTION_ARN environment variable is set
if [ -z "$CONNECTION_ARN" ]; then
  echo "Please set CONNECTION_ARN environment variable"
  exit 1
fi

cat > input.json << EOF
{
  "ServiceName": "reinvent-app",
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
          "StartCommand": "java -Dspring.profiles.active=h2 -jar target/spring-petclinic-3.1.0-SNAPSHOT.jar",
          "Port": "8080"
        }
      }
    }
  },
  "InstanceConfiguration": {
    "CPU": "2 vCPU",
    "Memory": "4 GB"
  }
}
EOF
SERVICE_ARN=$(aws apprunner create-service --cli-input-json file://input.json \
 --output text \
 --query 'Service.ServiceArn')

SERVICE_URL=$(aws apprunner describe-service --service-arn ${SERVICE_ARN} | jq -r '.Service.ServiceUrl')
echo "Service URL: ${SERVICE_URL}"
