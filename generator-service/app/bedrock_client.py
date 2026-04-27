import boto3
import json

# bedrock-runtime is the data-plane endpoint for model inference; it is separate from the
# bedrock control-plane (model management). The VPC interface endpoint resolves this hostname
# privately so traffic never leaves the VPC.
bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")


def invoke_claude_sonnet_4_6(prompt: str, max_tokens: int = 1000) -> dict:
    body = json.dumps({
        # anthropic_version is required by Bedrock's Anthropic integration and must be
        # exactly "bedrock-2023-05-31" regardless of the actual model version used.
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}]
    })
    response = bedrock.invoke_model(
        # Uses the cross-region inference profile (us.anthropic.*) rather than a direct
        # regional model ID. Bedrock automatically routes to us-east-1, us-east-2, or
        # us-west-2 for capacity; IAM must grant access to both the profile ARN and the
        # underlying foundation model ARNs in all three regions (see terraform/iam.tf).
        modelId="us.anthropic.claude-sonnet-4-6",
        body=body,
        contentType="application/json",
        accept="application/json"
    )
    result = json.loads(response["body"].read())
    return {
        # Claude returns a list of content blocks; index 0 is the primary text response.
        "text": result["content"][0]["text"],
        "input_tokens": result["usage"]["input_tokens"],
        "output_tokens": result["usage"]["output_tokens"]
    }
