# Terraform AWS S3 Bucket Replication and Serverless Application

This Terraform script provisions AWS S3 buckets, sets up replication from one bucket to another in different regions for disaster recovery, and deploys a serverless application using AWS Lambda, API Gateway, and CloudWatch Events.

## Features

- **S3 Buckets**: Creates two S3 buckets in different regions (one for replication/disaster recovery).
- **Bucket Replication**: Configures bucket replication from the source bucket to the destination bucket.
- **Versioning**: Sets up versioning on both buckets for object version control.
- **Serverless Application**: Deploys AWS Lambda functions to interact with S3 and handle serverless operations.
- **Event Triggering**: Enables CloudWatch Event triggering to execute Lambda functions periodically.
- **API Gateway**: Configures an API Gateway for invoking Lambda functions through HTTP requests.
- **Logging**: Sets up CloudWatch logging for monitoring of API Gateway requests and Lambda function invocations.

## Prerequisites

- AWS IAM credentials with necessary permissions.
- Terraform CLI installed on the local machine.
- AWS CLI configured with appropriate access keys and secret keys.

## Usage

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/supersilo/yahoo-assessment.git
   cd yahoo-assessment/aws

2. **Configure AWS Provider**:

Replace <YOUR_AWS_ACCESS_KEY> and <YOUR_AWS_SECRET_KEY> with your AWS access key and secret key in the `provider.tf` file.

3. **Initialize and Apply the Terraform Configuration**:
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve

4. **Accessing the Application**:
Once the Terraform script has successfully deployed the resources, you can interact with the serverless application using the provided API endpoint.

Open a web browser or API testing tool.

Enter the following URL in the address bar or send a GET request using the tool:
`<base_url>/timestamp`
Replace <base_url> with the base URL of the API Gateway deployed in the Terraform output. For example, if the API Gateway endpoint URL is https://abc123.execute-api.us-west-1.amazonaws.com, the complete URL to hit the timestamp endpoint would be `https://abc123.execute-api.us-west-1.amazonaws.com/timestamp`

Hit enter or send the request.
You should receive a JSON response similar to the following:
    ```json
    {
    "Decrypted content of the latest object": "2023-12-07 03:01:20"
    }

5. **Cleaning Up Resources**:
To destroy the provisioned infrastructure and clean up resources:
   ```bash
   terraform destroy

## Folder Structure
main.tf: Contains the Terraform configuration for provisioning resources.
variables.tf: Defines the input variables used in the Terraform configuration.
outputs.tf: Specifies the output values of the created resources.
provider.tf: Configures the AWS provider with access keys and secret keys.
