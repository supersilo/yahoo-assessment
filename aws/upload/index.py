import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    # AWS region
    region_name = os.environ["REGION"]

    # S3 bucket and KMS key details
    bucket_name = os.environ["BUCKET_NAME"]
    kms_key_id = os.environ["KMS_KEY_ID"]

    # Create an S3 client using default credentials from the environment or other sources
    s3_client = boto3.client('s3', region_name=region_name)

    # Generate timestamp
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    # Encrypt timestamp using KMS key
    kms_client = boto3.client('kms', region_name=region_name)
    response = kms_client.encrypt(KeyId=kms_key_id, Plaintext=timestamp.encode('utf-8'))
    encrypted_timestamp = response['CiphertextBlob']
    object_key = f'{timestamp}.txt' 

    s3_client.put_object(Bucket=bucket_name, Key=object_key, Body=encrypted_timestamp)

    return {
        'statusCode': 200,
        'body': f'Timestamped object "{object_key}" uploaded to bucket with encryption'
    }
