#!/usr/bin/env bash

CLUSTER_NAME="CLUSTER_NAME"
SERVICE_NAME="SERVICE_NAME"
REGION="AWS_REGION"

# Validate input
if [ -z "$1" ]; then
  echo "Usage: $0 <command>"
  echo "Example: $0 /bin/bash"
  exit 1
fi

# Command to run inside the container
COMMAND="$1"

# Step 1: Get the first task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --region "$REGION" \
  --query "taskArns[0]" \
  --output text)

if [ "$TASK_ARN" == "None" ]; then
  echo "No running tasks found for service $SERVICE_NAME in cluster $CLUSTER_NAME."
  exit 1
fi

# Step 2: Get container names in the task
CONTAINER_NAMES=$(aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --region "$REGION" \
  --query "tasks[0].containers[].name" \
  --output text)

# Check if containers exist
if [ -z "$CONTAINER_NAMES" ]; then
  echo "No containers found in the task $TASK_ARN."
  exit 1
fi

# Step 3: Display container options and prompt user to choose
echo "Containers available in the task:"
select CONTAINER_NAME in $CONTAINER_NAMES; do
  if [ -n "$CONTAINER_NAME" ]; then
    echo "You selected container: $CONTAINER_NAME"
    break
  else
    echo "Invalid selection. Please choose a valid container."
  fi
done

# Step 4: Attach to the selected container and run the custom command
echo "Attaching to container '$CONTAINER_NAME' in task '$TASK_ARN' and running command: $COMMAND..."
aws ecs execute-command \
  --cluster "$CLUSTER_NAME" \
  --task "$TASK_ARN" \
  --container "$CONTAINER_NAME" \
  --command "$COMMAND" \
  --interactive
