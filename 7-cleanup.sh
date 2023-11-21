export VPC_CONNECTOR_NAME=reinvent-2023-vpc-connector
export CONNECTION_NAME=reinvent-2023-connection
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export ROLE_NAME=AppRunnerSecretsRole
export WEB_ACL_NAME=reinvent-2023-web-acl

aws wafv2 disassociate-web-acl \
  --resource-arn arn:aws:apprunner:us-east-1:${AWS_ACCOUNT_ID}:service/4-security 

## Delete services
for i in $(aws apprunner list-services | jq -r '.ServiceSummaryList[].ServiceArn'); do    
    #if service name doesn't end with precreated, then dont delete it
    if [[ $i == *"precreated"* ]]; then
        echo "Skipping $i"
        continue
    fi
    aws apprunner delete-service --service-arn $i
done

## List VPC connector and dont delete if the name is precreated
for i in $(aws apprunner list-vpc-connectors | jq -r '.VpcConnectors[].VpcConnectorArn'); do        
    if [[ $i == *"precreated"* ]]; then
        echo "Skipping $i"
        continue
    fi
    aws apprunner delete-vpc-connector --vpc-connector-arn $i
done

## Delete Code connection
aws apprunner delete-connection --connection-arn $(aws apprunner list-connections --connection-name ${CONNECTION_NAME} | jq -r '.ConnectionSummaryList[0].ConnectionArn')

## Delete resources
aws iam delete-role-policy --role-name $ROLE_NAME --policy-name AppRunnerSecretsPolicy
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
aws iam delete-role --role-name $ROLE_NAME