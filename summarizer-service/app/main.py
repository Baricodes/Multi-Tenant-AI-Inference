import os
import time
import uuid
import boto3
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from app.bedrock_client import invoke_claude_haiku

app = FastAPI(title="Summarizer Service")
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE", "ai-inference-logs"))

class SummarizeRequest(BaseModel):
    text: str
    max_length: int = 200

class SummarizeResponse(BaseModel):
    summary: str
    request_id: str
    latency_ms: float

@app.get("/health")
def health():
    return {"status": "healthy", "service": "summarizer"}

@app.post("/summarize", response_model=SummarizeResponse)
async def summarize(
    request: SummarizeRequest,
    x_tenant_id: str = Header(..., alias="X-Tenant-ID")
):
    request_id = str(uuid.uuid4())
    start = time.time()

    prompt = f"Summarize the following text in {request.max_length} words or fewer:\n\n{request.text}"
    
    try:
        result = invoke_claude_haiku(prompt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Bedrock error: {str(e)}")

    latency_ms = round((time.time() - start) * 1000, 2)

    # Log to DynamoDB
    table.put_item(Item={
        "request_id": request_id,
        "tenant_id": x_tenant_id,
        "service": "summarizer",
        "model": "claude-3-haiku",
        "latency_ms": int(latency_ms),
        "input_tokens": result["input_tokens"],
        "output_tokens": result["output_tokens"],
        "timestamp": int(time.time())
    })

    return SummarizeResponse(
        summary=result["text"],
        request_id=request_id,
        latency_ms=latency_ms
    )
