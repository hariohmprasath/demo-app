export VPC_CONNECTOR_NAME=reinvent-2023-vpc-connector
export CONNECTION_NAME=reinvent-2023-connection
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

export CONNECTION_ARN=$(aws apprunner list-connections --connection-name ${CONNECTION_NAME} | jq -r '.ConnectionSummaryList[0].ConnectionArn')
echo "Connection ARN: ${CONNECTION_ARN}"

# 0-Create VPC connector
export VPC_CONNECTOR_ARN=$(aws apprunner create-vpc-connector \
  --vpc-connector-name=$VPC_CONNECTOR_NAME \
  --subnets="subnet-8bd57bd4" \
  --security-groups=sg-83951bbf \
  --output text \
  --query 'VpcConnector.VpcConnectorArn')
echo "VPC Connector ARN: ${VPC_CONNECTOR_ARN}"

# 1-Create instance role
export TP_FILE=$(mktemp)
export ROLE_NAME=AppRunnerSecretsRole
cat <<EOF | tee $TP_FILE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "tasks.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

cat <<EOF | tee permission.json
{
    "Version": "2012-10-17",
    "Statement": [        
        {
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:us-east-1:775448517459:secret:rds!cluster-41dd684c-d9d9-452b-b304-7ac0b0bc241c-fETtN0",
            "Effect": "Allow"
        }
    ]
}
EOF
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://$TP_FILE
aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name AppRunnerSecretsPolicy \
    --policy-document file://permission.json
rm $TP_FILE

# 2-Create service
rm -Rf network.json && cat > network.json << EOF
{
  "ServiceName": "3-networking",
  "NetworkConfiguration": {
    "EgressConfiguration": {
      "EgressType": "VPC",
      "VpcConnectorArn": "${VPC_CONNECTOR_ARN}"
    }
  },
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
          "StartCommand": "java -Dspring.profiles.active=mysql -jar target/spring-petclinic-3.1.0-SNAPSHOT.jar",
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
SERVICE_ARN=$(aws apprunner create-service --cli-input-json file://network.json \
 --output text \
 --query 'Service.ServiceArn')
echo "Service ARN: ${SERVICE_ARN}"

SERVICE_URL=$(aws apprunner describe-service --service-arn ${SERVICE_ARN} | jq -r '.Service.ServiceUrl')
echo "Service URL: ${SERVICE_URL}"

