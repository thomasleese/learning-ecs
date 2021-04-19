# Learning ECS

Learning AWS ECS.

## How to

### Initialise

```sh
terraform init
```

This installs the required Terraform modules and sets up your state.

Make sure your AWS credentials are exported for all the subsequent commands:

```sh
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

### Plan

```sh
terraform plan
```

### Apply

```sh
terraform apply
```

### Upload image to ECR

The image for the `service` will need to be built and upload to your ECR that was
created in the previous step.
