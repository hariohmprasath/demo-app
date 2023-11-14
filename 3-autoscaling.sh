cat > autoscaling.json << EOF
{
    "AutoScalingConfigurationName": "high-availability",
    "MaxConcurrency": 30,
    "MinSize": 1,
    "MaxSize": 10
}
EOF
AUTO_SCALING_ARN=$(aws apprunner create-auto-scaling-configuration --cli-input-json file://autoscaling.json \
 --output text \
 --query 'AutoScalingConfiguration.AutoScalingConfigurationArn')


aws apprunner update-service --service-arn ${SERVICE_ARN} --auto-scaling-configuration-arn ${AUTO_SCALING_ARN}
echo "Service update started"
