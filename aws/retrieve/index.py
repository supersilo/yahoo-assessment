import boto3
import os
import json

region_name = os.environ["REGION"]
bucket_name = os.environ["BUCKET_NAME"]
kms_key_id = os.environ["KMS_KEY_ID"]

s3_client = boto3.client('s3', region_name=region_name)
kms_client = boto3.client('kms', region_name=region_name)

def lambda_handler(event, context):
    try:
        # Get the list of objects in the bucket
        response = s3_client.list_objects_v2(Bucket=bucket_name)

        if 'Contents' in response:
            # Get the latest uploaded object based on the LastModified timestamp
            latest_object = max(response['Contents'], key=lambda obj: obj['LastModified'])
            object_key = latest_object['Key']

            # Retrieve the content of the latest object
            encrypted_content = s3_client.get_object(Bucket=bucket_name, Key=object_key)['Body'].read()

            # Decrypt the content using the KMS key
            decrypted_content = kms_client.decrypt(KeyId=kms_key_id, CiphertextBlob=encrypted_content)['Plaintext'].decode('utf-8')

            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                },
                'body': json.dumps({
                    'Decrypted content of the latest object': decrypted_content,
                }),
            }
        else:
            return {
                'statusCode': 404,
                'body': 'No objects found in the bucket.'
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }
