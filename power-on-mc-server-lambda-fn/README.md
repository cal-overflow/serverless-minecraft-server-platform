# power-on-mc-server-lambda-fn
Lambda function that powers on a ECS-based-infra Minecraft Server


## Helpful docs
  - [Creating lambda container image](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html).
  - [Boto3 Managing EC2 instances](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/ec2-example-managing-instances.html).

### Build docker image
```bash
docker build -t <tag_name>
```

### Run container
```bash
docker run <tag_name>
```

### Environment variables (required)
- `REGION`
- `CLUSTER`: name of the cluster
- `SERVICE`: name of the service
- `TASK_DEFINITION`: ARN of the TaskDefinition to use when updating the desiredCount value of the ECS Service
- `SUBNET`: ID of the subnet to use when updating the desiredCount value of the ECS Service
- `SECURITY_GROUPS`: List of ID's of the security groups to use when updating the desiredCount value of the ECS Service. This should be a string with commas seperating each ID (i.e., `"sg-1234,sg-456"`)

