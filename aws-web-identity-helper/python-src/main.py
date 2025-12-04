import json
import boto3
import os

# Define the expected shared key value here
EXPECTED_SHARED_KEY = 'hegerdes'
aws_sts_client = boto3.Session().client('sts', region_name='eu-central-1')
GLOBAL_TAGS = [
    {'Key': 'account', 'Value': os.environ.get('AWS_ACCOUNT', 'unknown')},
    {'Key': 'region', 'Value': os.environ.get('AWS_REGION', 'unknown')},
    {'Key': 'app', 'Value': os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'default')},
    {'Key': 'role', 'Value': os.environ.get('AWS_ROLE_NAME', 'unknown')},
    {'Key': 'issuer', 'Value': os.environ.get('OIDC_ISSUER', 'unknown')},
    {
        'Key': 'app_version',
        'Value': os.environ.get('AWS_LAMBDA_FUNCTION_VERSION', 'unknown').replace(
            '$', ''
        ),
    },
]


def handler(event, context):
    # Extract headers from the event
    headers = event.get('headers') or {}
    shared_key = headers.get('my-shared-key')
    audience = 'https://hegerdes.com'

    if shared_key == EXPECTED_SHARED_KEY:
        tags = [
            {'Key': 'origin', 'Value': headers.get('host', 'unknown')},
            {'Key': 'user', 'Value': headers.get('x-forwarded-for', 'unknown')},
        ]
        print(GLOBAL_TAGS + tags)
        response_body = {
            'message': 'Shared key validated successfully',
            'token': authenticate_with_web_id(audience, GLOBAL_TAGS + tags),
        }

        status_code = 200
    else:
        response_body = {'error': 'Invalid or missing My-Shared-Key header'}
        status_code = 401

    return {
        'statusCode': status_code,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(response_body),
    }


def authenticate_with_web_id(audience: str, tags: dict = {}):
    # Docs: https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/sts/client/get_web_identity_token.html
    """Get JWT using AWS STS client."""
    print(f"Using boto {boto3.__version__}")
    aws_token = aws_sts_client.get_web_identity_token(
        Audience=[audience], DurationSeconds=300, SigningAlgorithm='ES384', Tags=tags
    )['WebIdentityToken']

    return aws_token


if __name__ == '__main__':
    print(f"Using boto {boto3.__version__}")
    import requests
    from jose import jwt
    from jose.exceptions import JWTError

    # Your OIDC provider's issuer URL (e.g., https://accounts.google.com)
    # Get url with aws iam get-outbound-web-identity-federation-info --output json
    issuer = 'https://xxx.tokens.sts.global.api.aws/'

    # Your expected audience (client ID)
    audience = 'hegerdes'

    # The JWT token you want to verify
    token = 'xxxx'

    def get_jwks_uri(issuer):
        # Fetch OIDC discovery document
        resp = requests.get(f"{issuer}/.well-known/openid-configuration")
        resp.raise_for_status()
        return resp.json()['jwks_uri']

    def get_jwks(jwks_uri):
        resp = requests.get(jwks_uri)
        resp.raise_for_status()
        return resp.json()

    def verify_token(token, jwks, audience, issuer):
        # The jose library can handle JWKS keys directly
        try:
            claims = jwt.decode(
                token, jwks, algorithms=['ES384'], audience=audience, issuer=issuer
            )
            return claims
        except JWTError as e:
            print('Token verification failed:', e)
            return None

    jwks_uri = get_jwks_uri(issuer)
    jwks = get_jwks(jwks_uri)
    print(jwks)
    claims = verify_token(token, jwks['keys'][1], audience, issuer)
    if claims:
        print('Token is valid. Claims:')
        print(claims)
    else:
        print('Invalid token')
