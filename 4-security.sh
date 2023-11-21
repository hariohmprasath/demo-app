export VPC_CONNECTOR_NAME=reinvent-2023-vpc-connector
export CONNECTION_NAME=reinvent-2023-connection
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export WEB_ACL_NAME=reinvent-2023-web-acl
export ROLE_NAME=AppRunnerSecretsRole

export CONNECTION_ARN=$(aws apprunner list-connections --connection-name ${CONNECTION_NAME} | jq -r '.ConnectionSummaryList[0].ConnectionArn')
export VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors | jq -r '.VpcConnectors[0].VpcConnectorArn')

# 1-Create web ACL and stop SQL injection
rm -Rf waf-rules.json && cat > waf-rules.json << EOF
[
   {
      "Name":"SQLInjection",
      "Priority":0,
      "Statement":{
         "SqliMatchStatement":{
            "FieldToMatch":{
               "AllQueryArguments":{
                  
               }
            },
            "TextTransformations":[
               {
                  "Priority":0,
                  "Type":"NONE"
               }
            ]
         }
      },
      "Action":{
         "Block":{
            
         }
      },
      "VisibilityConfig":{
         "CloudWatchMetricsEnabled":true,
         "MetricName":"SQLInjection",
         "SampledRequestsEnabled":true
      }
   }
]
EOF
export WEB_ACL_ARN=$(aws wafv2 create-web-acl \
  --name ${WEB_ACL_NAME} \
  --scope REGIONAL \
  --default-action Allow={} \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=TestWebAclMetrics \
  --rules file://waf-rules.json \
  --output text \
  --query 'Summary.ARN')
echo "Web ACL ARN: ${WEB_ACL_ARN}"

# 2-Create service
rm -Rf security.json && cat > security.json << EOF
{
  "ServiceName": "4-security",
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
SERVICE_ARN=$(aws apprunner create-service --cli-input-json file://security.json \
 --output text \
 --query 'Service.ServiceArn')
echo "Service ARN: ${SERVICE_ARN}"

SERVICE_URL=$(aws apprunner describe-service --service-arn ${SERVICE_ARN} | jq -r '.Service.ServiceUrl')
echo "Service URL: ${SERVICE_URL}"

# 4- Associate web ACL, Explain the process before next step
aws wafv2 associate-web-acl --resource-arn ${SERVICE_ARN} --web-acl-arn ${WEB_ACL_ARN}

