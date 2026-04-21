import boto3
import json
import os

bedrock = boto3.client("bedrock-runtime", region_name=os.getenv("AWS_REGION", "us-east-1"))


def invoke_titan_embed_v2(text: str) -> dict:
    body = json.dumps({
        "inputText": text,
        "normalize": True,
    })
    response = bedrock.invoke_model(
        modelId="amazon.titan-embed-text-v2:0",
        body=body,
        contentType="application/json",
        accept="application/json"
    )
    result = json.loads(response["body"].read())
    return {
        "embedding": result["embedding"],
        "input_tokens": result.get("inputTextTokenCount", 0),
    }
