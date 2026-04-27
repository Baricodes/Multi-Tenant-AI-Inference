import boto3
import json

# bedrock-runtime is the data-plane endpoint for model inference; it is separate from the
# bedrock control-plane (model management). The VPC interface endpoint resolves this hostname
# privately so traffic never leaves the VPC.
bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")


def invoke_titan_embed_v2(text: str) -> dict:
    body = json.dumps({
        "inputText": text,
        # normalize=True L2-normalises the output vector so cosine similarity can be computed
        # with a simple dot product, which is cheaper at query time.
        "normalize": True,
    })
    response = bedrock.invoke_model(
        # Full model ID including version suffix (:0) is required by Bedrock's invoke API.
        modelId="amazon.titan-embed-text-v2:0",
        body=body,
        contentType="application/json",
        accept="application/json"
    )
    result = json.loads(response["body"].read())
    return {
        "embedding": result["embedding"],
        # inputTextTokenCount reflects the tokenisation performed by Titan before embedding;
        # it is used for cost attribution in the DynamoDB log entry.
        "input_tokens": result.get("inputTextTokenCount", 0),
    }
