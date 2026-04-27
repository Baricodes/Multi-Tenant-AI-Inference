import os
import time
import uuid
import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from app.bedrock_client import invoke_titan_embed_v2

app = FastAPI(title="Embedder Service")

# DynamoDB client is initialised at module load so the connection is reused across requests.
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE", "ai-inference-logs"))

# TENANT_ID is injected by the Kubernetes Deployment manifest for each tenant namespace
# (tenant-a / tenant-b). It must never be trusted from caller-supplied request headers.
tenant_id = os.getenv("TENANT_ID", "tenant-a")

# 7 776 000 seconds = 90 days. DynamoDB TTL deletes items after this epoch offset.
log_ttl_seconds = int(os.getenv("LOG_TTL_SECONDS", "7776000"))

class EmbedRequest(BaseModel):
    text: str

class EmbedResponse(BaseModel):
    embedding: list[float]
    request_id: str
    latency_ms: float

# Three routes share the same handler so the service responds correctly whether reached
# directly (bare /health) or via the ALB Ingress path-based rules (/tenant-a/health, /tenant-b/health).
@app.get("/tenant-a/health")
@app.get("/tenant-b/health")
@app.get("/health")
def health():
    return {"status": "healthy", "service": "embedder"}

@app.post("/tenant-a/embed", response_model=EmbedResponse)
@app.post("/tenant-b/embed", response_model=EmbedResponse)
@app.post("/embed", response_model=EmbedResponse)
async def embed(request: EmbedRequest):
    request_id = str(uuid.uuid4())
    start = time.time()

    try:
        result = invoke_titan_embed_v2(request.text)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Bedrock error: {str(e)}")

    latency_ms = round((time.time() - start) * 1000, 2)
    timestamp = int(time.time())

    # Embeddings produce no output tokens; store 0 so downstream queries
    # can aggregate token counts uniformly across all three service types.
    table.put_item(Item={
        "request_id": request_id,
        "tenant_id": tenant_id,
        "service": "embedder",
        "model": "titan-embed-text-v2",
        "latency_ms": int(latency_ms),
        "input_tokens": result["input_tokens"],
        "output_tokens": 0,
        "timestamp": timestamp,
        # Absolute Unix epoch at which DynamoDB will expire this item.
        "ttl": timestamp + log_ttl_seconds,
    })

    return EmbedResponse(
        embedding=result["embedding"],
        request_id=request_id,
        latency_ms=latency_ms
    )
