import boto3
import json

bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")


def invoke_claude_sonnet_4_6(prompt: str, max_tokens: int = 1000) -> dict:
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}]
    })
    response = bedrock.invoke_model(
        modelId="us.anthropic.claude-sonnet-4-6",
        body=body,
        contentType="application/json",
        accept="application/json"
    )
    result = json.loads(response["body"].read())
    return {
        "text": result["content"][0]["text"],
        "input_tokens": result["usage"]["input_tokens"],
        "output_tokens": result["usage"]["output_tokens"]
    }
