# README

Requirements:
- awscli.
- any authentication tools required to authenticate to your AWS account, e.g. `saml2aws`.

How to use:

## To Delete per Account

1. Prepare your AWS profile, use region endpoint instead of global endpoint, e.g. ap-southeast-2

    ```bash
    AWS_PROFILE=<profile>
    AWS_DEFAULT_REGION=us-east-2
    export AWS_PROFILE AWS_DEFAULT_REGION
    ```

2. Run the script

    ```bash
    ./cleanup-default-vpc.sh
    ```
    OR if your resources are in a specific region, e.g. `ap-southeast-2` and you want to exclude your that region from the script, run:

    ```bash
    ./cleanup-default-vpc.sh "ap-southeast-2"
    ```
