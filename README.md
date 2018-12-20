# Government Shared Platform (come up with a better name please) - Teams

...

## Prerequisites

- [Docker Desktop](https://docs.docker.com/install/#supported-platforms) - Container tooling
- [aws-cli](https://github.com/aws/aws-cli) - Universal Command Line Interface for Amazon Web Services
- [aws-vault](https://github.com/99designs/aws-vault) - A vault for securely storing and accessing AWS credentials in development environments
- [aws-iam-authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator) - A tool to use AWS IAM credentials to authenticate to a Kubernetes cluster
  - `go get -u -v github.com/kubernetes-sigs/aws-iam-authenticator/cmd/aws-iam-authenticator`

## How to register a new cluster

1. Manually `Create S3 Bucket` in the Service Team's AWS account
    * `Bucket name` should resolve to
      `gds-re-${AWS_ACCOUNT_NAME}-terraform-state`
    * `Versioning` should be opt in
    * `Default encryption` should be opt in
1. Manually `Create Hosted Zone` in the Service Team's AWS account
    * `Domain Name` should resolve to
      `${AWS_ACCOUNT_NAME}.${CLOUD}.ext.govsvc.uk`
    * `Type` should be set to `Public Hosted Zone`
    * Take a note of:
        * `Hosted Zone ID`
        * `Domain Name`
        * Zone's `NS` record type values
1. In the `run-production` AWS account, `Create Record Set` in the already
   existing Hosted Zone
   * `Name` field needs to match the `Domain Name` from the previous step
   * `Type` field needs to be set to `NS - Name Server`
   * `Value` field needs to contain the `NS` records obtained from the Service
     Team's AWS account
1. Create cluster

    From this point onwards, you will need some environment variables defined:

    | Variable | Description | Example |
    |---|---|---|
    | `CLOUD` | The cloud provider. | `aws` |
    | `AWS_ACCOUNT_NAME` | This should match your AWS account name or the account ID. | `re-managed-observe-production` |
    | `AWS_REGION` | Should represent AWS region. Stick to London. | `eu-west-2` |
    | `AWS_DEFAULT_REGION` | Default AWS region. | `eu-west-2` |
    | `CLUSTER_NAME` | The name of the cluster about to be created. Needs to be unique across your entire Hosted Zone. | `cluster1` |
    | `ZONE_ID` | An AWS Hosted Zone ID which you've obtained from the first step of this guide. | `Z00000000000` |
    | `ZONE_NAME` | An AWS Hosted Zone name which you've obtained from the first step of this guide. | `re-managed-observe-production.aws.ext.govsvc.uk` |

    We've prepared a [templater script](https://github.com/alphagov/gsp-teams/blob/master/scripts/create_cluster_config.sh) to create the new cluster terraform declaration based on a [terraform template](https://github.com/alphagov/gsp-teams/blob/master/terraform/templates/cluster.tf)

    With the above variables you can run:

    ```sh
    aws-vault exec run-sandbox -- ./scripts/create_cluster_config.sh
    ```

    This should generate new file at the location:

    ```
    terraform/clusters/${CLUSTER}.${AWS_ACCOUNT_NAME}.${CLOUD}.ext.govsvc.uk/cluster.tf
    ```

    This leaves you with a manual steps of:

    ```sh
    export DOMAIN=${CLUSTER}.${AWS_ACCOUNT_NAME}.${CLOUD}.ext.govsvc.uk
    cd terraform/clusters/${DOMAIN}

    # initialise terraform
    aws-vault exec run-sandbox -- docker run -it \
      --env AWS_DEFAULT_REGION \
      --env AWS_REGION \
      --env AWS_ACCESS_KEY_ID \
      --env AWS_SECRET_ACCESS_KEY \
      --env AWS_SESSION_TOKEN \
      --env AWS_SECURITY_TOKEN \
      --env DOMAIN \
      --volume=$(pwd)/../../../:/terraform \
      -w /terraform/terraform/clusters/${DOMAIN} \
      govsvc/terraform init

    # check the plan
    aws-vault exec run-sandbox -- docker run -it \
      --env AWS_DEFAULT_REGION \
      --env AWS_REGION \
      --env AWS_ACCESS_KEY_ID \
      --env AWS_SECRET_ACCESS_KEY \
      --env AWS_SESSION_TOKEN \
      --env AWS_SECURITY_TOKEN \
      --env DOMAIN \
      --volume=$(pwd)/../../../:/terraform \
      -w /terraform/terraform/clusters/${DOMAIN} \
      govsvc/terraform plan

    # apply the plan
    aws-vault exec run-sandbox -- docker run -it \
      --env AWS_DEFAULT_REGION \
      --env AWS_REGION \
      --env AWS_ACCESS_KEY_ID \
      --env AWS_SECRET_ACCESS_KEY \
      --env AWS_SESSION_TOKEN \
      --env AWS_SECURITY_TOKEN \
      --env DOMAIN \
      --volume=$(pwd)/../../../:/terraform \
      -w /terraform/terraform/clusters/${DOMAIN} \
      govsvc/terraform apply
    ```

1. Test the connection to Kubernetes by executing the following:
    ```
    cp $(pwd)/bootkube-assets/auth/user-config ./kubeconfig
    export KUBECONFIG="$(pwd)/kubeconfig"
    aws-vault exec run-sandbox -- kubectl get all --all-namespaces
    ```

1. Apply any generated resources to the cluster:
   ```
    aws-vault exec run-sandbox -- kubectl apply -Rf addons/
   ```

1. Commit and Push new `cluster.tf` and `kubeconfig` files to keep the record.
