# EasyML Github Workflows

## So you've noticed these aren't in .github/workflows?

That's right, these workflows only make sense when you're deploying the EasyML gem as a standalone app (not mounting it in your Rails application).

If you do that, you can easily deploy the standalone application through AWS and Github actions using the...

## Build and Deploy to ECS Action

This workflow deploys the EasyML gem as a standalone app to AWS ECS, using Github actions.

## How To Setup AWS:

### 1. Create An ECR Repository

Name it easy_ml or similar

### 2. Create An ECS Cluster

- Use Fargate as the provider

### 3. Create A Task Definition

You can copy the task definition from the EasyML gem's repo, inside the `deployment` directory.

This will spin up a separate container for the web app and a separate container for the worker app.

### 4. Setup your AWS Secrets

You'll notice the task definition relies on a number of AWS secrets. These need to be created in AWS secrets manager.

You'll need:

- `POSTGRES_URL`
- `REDIS_URL`
- `SECRET_KEY_BASE`
- `ROLLBAR_ACCESS_TOKEN` (if you want to use Rollbar)

### 5. Create An EFS Volume

This will be used to share the data directory between the web and worker containers (plus if you want to run many web containers)

### 6. Setup Two Target Groups for a Blue/Green Deployment

- Use `Instance` mode, since we're using Fargate
- Setup the `Blue` target group as the main group
  - Send healthchecks to /easy_ml/healthcheck using HTTP
  - Use port `8080`
