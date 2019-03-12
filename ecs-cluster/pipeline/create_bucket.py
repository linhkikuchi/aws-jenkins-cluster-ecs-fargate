import sys
import boto3
# boto3.setup_default_session(profile_name=sys.argv[1])


def create_bucket(this_bucket):
    s3 = boto3.resource('s3')
    client = boto3.client('s3')
    bucket = s3.Bucket(this_bucket)
    try:
        if sys.argv[2] == 'us-east-1':
            response = bucket.create(
                ACL='private',
                Bucket=this_bucket,
            )
        else:
            response = bucket.create(
                ACL='private',
                Bucket=this_bucket,
                CreateBucketConfiguration={
                    'LocationConstraint': sys.argv[2]},
            )
        print response
    except Exception as e:
        print e
        pass
    try:
        response = client.put_bucket_encryption(
            Bucket=this_bucket,
            ServerSideEncryptionConfiguration={
                'Rules': [
                    {
                        'ApplyServerSideEncryptionByDefault': {
                            'SSEAlgorithm': 'aws:kms'
                        }
                    },
                ]
            }
        )
        print response
    except Exception as e:
        print e
        pass
    try:
        response = client.put_bucket_versioning(
            Bucket=this_bucket,
            VersioningConfiguration={
                'Status': 'Enabled'
            }
        )
        print response
    except Exception as e:
        print e
        pass

if __name__ == "__main__":
    create_bucket(sys.argv[1])