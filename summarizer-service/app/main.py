import os
import time
import uuid
import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from app.bedrock_client import invoke_claude_haiku

app = FastAPI(title="Summarizer Service")

# DynamoDB client is initialised at module load so the connection is reused across requests.
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE", "ai-inference-logs"))

# TENANT_ID is injected by the Kubernetes Deployment manifest for each tenant namespace
# (tenant-a / tenant-b). It must never be trusted from caller-supplied request headers.
tenant_id = os.getenv("TENANT_ID", "tenant-a")

# 7 776 000 seconds = 90 days. DynamoDB TTL deletes items after this epoch offset.
log_ttl_seconds = int(os.getenv("LOG_TTL_SECONDS", "7776000"))

class SummarizeRequest(BaseModel):
    text: str
    max_length: int = 200

class SummarizeResponse(BaseModel):
    summary: str
    request_id: str
    latency_ms: float

# Three routes share the same handler so the service responds correctly whether reached
# directly (bare /health) or via the ALB Ingress path-based rules (/tenant-a/health, /tenant-b/health).
@app.get("/tenant-a/health")
@app.get("/tenant-b/health")
@app.get("/health")
def health():
    return {"status": "healthy", "service": "summarizer"}

@app.post("/tenant-a/summarize", response_model=SummarizeResponse)
@app.post("/tenant-b/summarize", response_model=SummarizeResponse)
@app.post("/summarize", response_model=SummarizeResponse)
async def summarize(request: SummarizeRequest):
    request_id = str(uuid.uuid4())
    start = time.time()

    # max_length is phrased as a word count in the instruction so the model
    # naturally self-truncates rather than having Bedrock hard-cut the tokens.
    prompt = f"Summarize the following text in {request.max_length} words or fewer:\n\n{request.text}"
    
    try:
        result = invoke_claude_haiku(prompt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Bedrock error: {str(e)}")

    latency_ms = round((time.time() - start) * 1000, 2)
    timestamp = int(time.time())

    # Tenant identity is deployment-owned; do not trust caller-supplied headers.
    table.put_item(Item={
        "request_id": request_id,
        "tenant_id": tenant_id,
        "service": "summarizer",
        "model": "claude-3-haiku",
        "latency_ms": int(latency_ms),
        "input_tokens": result["input_tokens"],
        "output_tokens": result["output_tokens"],
        "timestamp": timestamp,
        # Absolute Unix epoch at which DynamoDB will expire this item.
        "ttl": timestamp + log_ttl_seconds,
    })

    return SummarizeResponse(
        summary=result["text"],
        request_id=request_id,
        latency_ms=latency_ms
    )
