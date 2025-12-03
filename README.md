# terraform-aws-ecs-service

This module creates an ECS service. It supports load balanced services if required.

Has additional security measures that can be optionally enabled, such as RO filesystem, or "run as specified user".

## Enabling Fargate

To run the service on Fargate, set the following required variables:

```hcl
fargate         = true
fargate_spot    = false  # Set to true for Fargate Spot
cpu             = 256    # Required for Fargate
memory          = 512    # Required for Fargate
```

Optional autoscaling configuration:

```hcl
use_fargate_scaling         = true
fargate_min_capacity        = 2
fargate_max_capacity        = 10
fargate_cpu_target_value    = 70
fargate_memory_target_value = 85
desired_count               = 2  # Should match min_capacity when using autoscaling
```
