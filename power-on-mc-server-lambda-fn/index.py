import boto3
import os

region = os.environ.get('REGION')
cluster = os.environ.get('CLUSTER')
service = os.environ.get('SERVICE')
task_definition = os.environ.get('TASK_DEFINITION')
subnet = os.environ.get('SUBNET')
security_groups = os.environ.get('SECURITY_GROUPS')

security_groups_list = security_groups.replace(' ', '').split(',')



ecs = boto3.client('ecs', region_name=region)


def lambda_handler(event, context):
    response = ecs.describe_services(
        cluster=cluster,
        services=[service]
    )

    current_desired_count = response['services'][0]['desiredCount']

    if current_desired_count == 0:
        ecs.update_service(
            cluster=cluster,
            service=service,
            desiredCount=1,
            taskDefinition=task_definition,
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': [subnet],
                    'securityGroups': security_groups_list,
                    'assignPublicIp': 'ENABLED'
                }
            },
        )
        print('Set desired task count to 1')
    else:
        print('Desired task count was already at 1')

