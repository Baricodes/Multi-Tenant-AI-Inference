import os
import time
import uuid
import boto3
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from app.bedrock_client import invoke_titan_embed_v2

app = FastAPI(title="Embedder Service")
dynamodb = boto3.resource("dynamodb", region_name=os.getenv("AWS_REGION", "us-east-1"))
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE", "ai-inference-logs"))

class EmbedRequest(BaseModel):
    text: str

class EmbedResponse(BaseModel):
    embedding: list[float]
    request_id: str
    latency_ms: float

@app.get("/health")
def health():
    return {"status": "healthy", "service": "embedder"}

@app.post("/embed", response_model=EmbedResponse)
async def embed(
    request: EmbedRequest,
    x_tenant_id: str = Header(..., alias="X-Tenant-ID")
):
    request_id = str(uuid.uuid4())
    start = time.time()

    try:
        result = invoke_titan_embed_v2(request.text)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Bedrock error: {str(e)}")

    latency_ms = round((time.time() - start) * 1000, 2)

    table.put_item(Item={
        "request_id": request_id,
        "tenant_id": x_tenant_id,
        "service": "embedder",
        "model": "titan-embed-text-v2",
        "latency_ms": int(latency_ms),
        "input_tokens": result["input_tokens"],
        "output_tokens": 0,
        "timestamp": int(time.time())
    })

    return EmbedResponse(
        embedding=result["embedding"],
        request_id=request_id,
        latency_ms=latency_ms
    )
