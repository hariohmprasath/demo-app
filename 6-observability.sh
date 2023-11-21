export VPC_CONNECTOR_NAME=reinvent-2023-vpc-connector
export CONNECTION_NAME=reinvent-2023-connection
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export AUTO_SCALING_CONFIG_NAME=high-availability
export ROLE_NAME=AppRunnerSecretsRole

export CONNECTION_ARN=$(aws apprunner list-connections --connection-name ${CONNECTION_NAME} | jq -r '.ConnectionSummaryList[0].ConnectionArn')
export VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors | jq -r '.VpcConnectors[0].VpcConnectorArn')

# 1-Create observability configuration
rm -Rf observability-config.json && cat > autoscaling-config.json << EOF
{
    "AutoScalingConfigurationName": "${AUTO_SCALING_CONFIG_NAME}",
    "MaxConcurrency": 30,
    "MinSize": 1,
    "MaxSize": 10
}
EOF
OBSERVABILITY_CONFIGURATION_ARN=$(aws apprunner create-observability-configuration \
    --observability-configuration-name otel-integration \
    --trace-configuration "Vendor=AWSXRAY" \
    --output text \
    --query 'ObservabilityConfiguration.ObservabilityConfigurationArn')

echo "Observability Configuration ARN: ${OBSERVABILITY_CONFIGURATION_ARN}"

# 2-Attach Policy
aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess

# 3-Create service
rm -Rf observability.json && cat > observability.json << EOF
{
  "ServiceName": "6-observability",
  "NetworkConfiguration": {
    "EgressConfiguration": {
      "EgressType": "VPC",
      "VpcConnectorArn": "${VPC_CONNECTOR_ARN}"
    }
  },
  "ObservabilityConfiguration": {
    "ObservabilityEnabled": true,
    "ObservabilityConfigurationArn": "${OBSERVABILITY_CONFIGURATION_ARN}"
  },
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "ConnectionArn": "${CONNECTION_ARN}"
    },
    "AutoDeploymentsEnabled": false,
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
          "StartCommand": "java -Dspring.profiles.active=mysql,xray -jar target/spring-petclinic-3.1.0-SNAPSHOT.jar",
          "Port": "8080",
          "RuntimeEnvironmentVariables": {
            "MYSQL_URL": "jdbc:mysql://reinvent-demo.cluster-c64elhmsvxbj.us-east-1.rds.amazonaws.com:3306/petclinic?createDatabaseIfNotExist=true"
          },          
          "RuntimeEnvironmentSecrets": {
              "MYSQL_PASS":"arn:aws:secretsmanager:us-east-1:775448517459:secret:rds!cluster-41dd684c-d9d9-452b-b304-7ac0b0bc241c-fETtN0:password::",
              "MYSQL_USER":"arn:aws:secretsmanager:us-east-1:775448517459:secret:rds!cluster-41dd684c-d9d9-452b-b304-7ac0b0bc241c-fETtN0:username::"
          }          
        }
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "2 vCPU",
    "Memory": "4 GB",
    "InstanceRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
  }
}
EOF

# 3-Print outputs
SERVICE_ARN=$(aws apprunner create-service --cli-input-json file://observability.json \
 --output text \
 --query 'Service.ServiceArn')
echo "Service ARN: ${SERVICE_ARN}"

SERVICE_URL=$(aws apprunner describe-service --service-arn ${SERVICE_ARN} | jq -r '.Service.ServiceUrl')
