import boto3
import json

# bedrock-runtime is the data-plane endpoint for model inference; it is separate from the
# bedrock control-plane (model management). The VPC interface endpoint resolves this hostname
# privately so traffic never leaves the VPC.
bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")


def invoke_claude_haiku(prompt: str, max_tokens: int = 1000) -> dict:
    body = json.dumps({
        # anthropic_version is required by Bedrock's Anthropic integration and must be
        # exactly "bedrock-2023-05-31" regardless of the actual model version used.
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}]
    })
    response = bedrock.invoke_model(
        # Haiku is invoked by its direct regional model ID (no cross-region inference profile)
        # because it is available in us-east-1 and does not require the multi-region routing
        # that Claude Sonnet uses. The full versioned ID is required by the Bedrock API.
        modelId="anthropic.claude-3-haiku-20240307-v1:0",
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
