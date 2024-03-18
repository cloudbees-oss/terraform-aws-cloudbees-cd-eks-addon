# CloudBees CI Add-on at scale Blueprint

Once you have familiarized yourself with the [Getting Started blueprint](../01-getting-started/README.md), this one presents a scalable architecture and configuration by adding:

- An [EFS Drive](https://aws.amazon.com/efs/) that can be used by non-HA/HS controllers (optional) and is required by HA/HS CBCI Controllers. It is managed by [AWS Backup](https://aws.amazon.com/backup/) for Backup and Restore.
- An [s3 Bucket](https://aws.amazon.com/s3/) to store assets from applications like CloudBees CI and Velero.
- [EKS Managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) for different workloads: CI Applications, CI On-Demand Agent, CI Spot Agents and K8s applications.
- [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) for Control plane logs and Applications Container Insights.
- The following **[Amazon EKS Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)**:
  - EKS Managed node groups are watched by [Cluster Autoscaler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cluster-autoscaler/) to accomplish [CloudBees auto-scaling nodes on EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/eks-auto-scaling-nodes) on defined EKS Managed node groups.
  - [EFS CSI Driver](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/) to connect EFS Drive to the EKS Cluster.
  - The [Metrics Server](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/metrics-server/) is required by CBCI HA/HS Controllers for Horizontal Pod Autoscaling.
  - [Velero](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/velero/) for Backup and Restore of Kubernetes Resources and Volumen snapshot (EBS compatible only).
  - [Kube Prometheus Stack](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/kube-prometheus-stack/) is used for Metrics Observability.
  - [AWS for Fluent Bit](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-for-fluentbit/) acts as an Applications log router for Log Observability in CloudWatch.
- Cloudbees CI uses [Configuration as Code](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/casc-intro) to enable [New Features for Streamlined DevOps](https://www.cloudbees.com/blog/cloudbees-ci-exciting-new-features-for-streamlined-devops) as well as other enterprise features and configurations.

> [!TIP]
> A [Resource Group](https://docs.aws.amazon.com/ARG/latest/userguide/resource-groups.html) is added to get a full list with all resources created by this blueprint.

## Architecture

![Architecture](img/at-scale.architect.drawio.svg)

> [!NOTE]
> For s3 storage permissions for Workspace caching and Artifact Manager is based on [Instance Profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) rather than creating an User with IAM permissions. Then, it is expected that Credentials validation fails from CloudBees CI.

### Kubernetes Cluster

![Architecture](img/at-scale.k8s.drawio.svg)

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| host_name | Host name. CloudBees CD Apps is configured to use this host name. | `string` | n/a | yes |
| hosted_zone | Route 53 Hosted Zone. CloudBees CI Apps is configured to use subdomains in this Hosted Zone. | `string` | n/a | yes |
| suffix | Unique suffix to be assigned to all resources | `string` | `""` | no |
| tags | Tags to apply to resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | ACM certificate ARN |
| aws_backup_efs_protected_resource | AWS Backup Protected Resource descriction for EFS Drive. |
| cbcd_helm | Helm configuration for CloudBees CI Add-on. It is accesible only via state files. |
| cbcd_namespace | Namespace for CloudBees CI Add-on. |
| cbcd_password | command to get the admin password of Cloudbees CD |
| cbcd_url | URL of the CloudBees CD Operations Center for CloudBees CD Add-on. |
| efs_access_points | EFS Access Points. |
| efs_arn | EFS ARN. |
| eks_cluster_arn | EKS cluster ARN |
| kubeconfig_add | Add Kubeconfig to local configuration to access the K8s API. |
| s3_cbcd_arn | cbcd s3 Bucket Arn |
| s3_cbcd_name | cbcd s3 Bucket Name. It is required by Velero for backup |
| velero_backup_on_demand_team_cd | Take an on-demand velero backup from the schedulle for Team A. |
| velero_backup_schedule_team_cd | Create velero backup schedulle for Team A, deleting existing one (if exists). It can be applied for other controllers using EBS. |
| velero_restore_team_cd | Restore Team A from backup. It can be applicable for rest of schedulle backups. |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->

## Deploy

Refer to the [Getting Started Blueprint - Deploy](../01-getting-started/README.md#deploy) section.

Additionally, the following is required:

- Customize your secrets file by copying `secrets-values.yml.example` to `secrets-values.yml`.
- In the case of using the terraform variable `suffix` for this blueprint, the Amazon `S3 Bucket Access settings` > `S3 Bucket Name` requires to be updated:
  - via UI (temporal update): Go to `Manage Jenkins` in the Controller > `AWS` > `Amazon S3 Bucket Access settings` > `S3 Bucket Name`.
  - via Casc (permanent update):
    - Make a fork from [cloudbees/casc-mm-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) to your organization, and update accordingly `cbci_s3` in `bp02.parent/variables/variables.yaml` file. Save and Push.
    - Make a fork from [cloudbees/casc-oc-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) to your organization, and update accordingly `scm_casc_mm_store` in `bp02/variables/variables.yaml` file. Save and Push.

## Validate

### CBCI

- Start by referring to the [Getting Started Blueprint - Validate](../01-getting-started/README.md#validate) but this time there will be three types of personas/users with a different set of permissions configured via [RBAC](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/rbac) for Operation Center and Controller using [Single Sign-On](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/using-sso). The password for all of them is the same:

  ```sh
  eval $(terraform output --raw cbci_general_password)
  ```

- Configuration as Code (CasC) is enabled for [Operation Center](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/) (`cjoc`) and [Controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/) (`team-b` and `team-c-ha`). `team-cd` is not using CasC to show the difference between the two approaches. Check that all Controllers are in `Running` state

  ```sh
  eval $(terraform output --raw cbci_controllers_pods)
  ```

> [!NOTE]
> - Controllers use [bundle inheritance](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/advanced#_configuring_bundle_inheritance_with_casc) see `bp02.parent`
> - Operation Center uses [Bundle Retrival Strategy](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/bundle-retrieval-scm)

> [!IMPORTANT]
> The declarative Casc defition overrides anything modified at UI (in case they overlap) at the next time the Controller is restarted.

- From the previous validation you can tell that 2 replicas running for `team-c-ha`. This is because [CloudBees CI HA/HS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha-install-guide/) is enabled in this controller, where you can follow the steps from [Getting Started With CloudBees CI High Availability - CloudBees TV 🎥](https://www.youtube.com/watch?v=Qkf9HaA2wio). See Horizontal Pod Autoscaling enabled by:

  ```sh
  eval $(terraform output --raw cbci_controller_c_hpa)
  ```

- [CloudBees Pipeline Explorer](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-pipeline-explorer-plugin) is enabled for all Controllers using Configuration as Code, where you can follow the steps explained in [Troubleshooting Pipelines With CloudBees Pipeline Explorer - CloudBees TV 🎥](https://www.youtube.com/watch?v=OMXm6eYd1EQ) with the items included in their bundle or by creating your own.

- [CloudBees Workspace Caching](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-cache-step) and [CloudBees CI Hibernation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_hibernation_in_managed_masters) features can be seen together in action the `team-b`. Once the `Amazon S3 Bucket Access settings` > `S3 Bucket Name` is configured correctly (see [Deploy](#deploy) section), you can watch how to write (since the first build) and read (since the second build) from the `ws-cache` pipeline. To trigger the builds will be using the [POST queue hibernation API endpoints](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_post_queue_for_hibernation). But firstly you need to [create an API TOKEN](https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/how-to-generate-change-an-apitoken#_programmatically_creating_a_token) for the `admin` user and then execute:

  ```sh
  eval $(terraform output --raw cbci_oc_export_admin_crumb) && \
    eval $(terraform output --raw cbci_oc_export_admin_api_token) && \
    eval $(terraform output --raw cbci_controller_b_hibernation_post_queue_ws_cache)
  ```

> [!NOTE]
> - More examples for Workspace Caching can be found at [Getting Started With CloudBees Workspace Caching on AWS S3 - CloudBees TV 🎥](https://www.youtube.com/watch?v=ESU9oN9JUCw&list=PLvBBnHmZuNQJcDefZ7G7Qyp3J9MAMaigF&index=7&t=3s)
> - `team-b` transitions to the hibernation state after the defined time in `unclassified.hibernationConfiguration.gracePeriod` (seconds) of inactivity (idle).

### Backups and Restores

- For EBS Storage is based on Velero.

  - Create a Velero Backup schedule for Team A to take regular backups. This can be also applied to Team B.

    ```sh
    eval $(terraform output --raw velero_backup_schedule_team_cd)
    ```

  - Velero Backup on a specific point in time for Team A. Note also there is a scheduled backup process in place.

    ```sh
    eval $(terraform output --raw velero_backup_on_demand_team_cd)
    ```

  - Velero Restore process: Make any update on `team-cd` (e.g.: adding some jobs), take a backup including the update, remove the latest update (e.g.: removing the jobs) and then restore it from the last backup as follows

    ```sh
    eval $(terraform output --raw velero_restore_team_cd)
    ```

- EFS Storage is protected in [AWS Backup](https://aws.amazon.com/backup/) with a regular Backup Plan. Additional On-Demand Backup can be created. Restore can be performed and item level (Access Points) or full restore.

  - Protected Resource

    ```sh
    eval $(terraform output --raw aws_backup_efs_protected_resource) | . jq
    ```

  - EFS Access point (they match with CloudBees CI `pvc`)

    ```sh
    eval $(terraform output --raw efs_access_points) | . jq .AccessPoints[].RootDirectory.Path
    ```

### Observability

- Metrics: The explanations from [How to Monitor Jenkins With Grafana and Prometheus - CloudBees TV 🎥](https://www.youtube.com/watch?v=3H9eNIf9KZs) are valid in this context but this blueprint relies on the [CloudBees Prometheus Metrics plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/monitoring/prometheus-plugin) and not the open-source version.

  - Check the CloudBees CI Targets are connected to Prometheus.

    ```sh
    eval $(terraform output --raw prometheus_active_targets) | jq '.data.activeTargets[] | select(.labels.container=="jenkins" or .labels.job=="cjoc") | {job: .labels.job, instance: .labels.instance, status: .health}'
    ```

  - Access to Kube Prometheus Stack dashboards from your web browser (Check that [Jenkins metrics](https://plugins.jenkins.io/metrics/) are available)

    - Prometheus will be available at `http://localhost:50001` after running the following command in your host:

    ```sh
    eval $(terraform output --raw prometheus_dashboard)
    ```  

    - Grafana will be available at `http://localhost:50002` after running the following command in your host:

    ```sh
    eval $(terraform output --raw grafana_dashboard)
    ```  

- Logs: Inside CloudWatch Logs Group `/aws/containerinsights/<CLUSTER_NAME>/application` can be found Log streams for all the K8s Services running in the cluster, including CloudBees CI Apps.

```sh
  eval $(terraform output --raw aws_fluentbit_logstreams) | jq '.[] | select(.logStreamName | contains("jenkins"))'
```

## Destroy

Refer to the [Getting Started Blueprint - Destroy](../01-getting-started/README.md#destroy) section.
