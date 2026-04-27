import os
import time
import uuid
import boto3
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from app.bedrock_client import invoke_claude_sonnet_4_6

app = FastAPI(title="Generator Service")
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE", "ai-inference-logs"))

class GenerateRequest(BaseModel):
    text: str
    max_length: int = 200

class GenerateResponse(BaseModel):
    generation: str
    request_id: str
    latency_ms: float

@app.get("/health")
def health():
    return {"status": "healthy", "service": "generator"}

@app.post("/generate", response_model=GenerateResponse)
async def generate(
    request: GenerateRequest,
    x_tenant_id: str = Header(..., alias="X-Tenant-ID")
):
    request_id = str(uuid.uuid4())
    start = time.time()

    prompt = f"Respond to the following in {request.max_length} words or fewer:\n\n{request.text}"

    try:
        result = invoke_claude_sonnet_4_6(prompt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Bedrock error: {str(e)}")

    latency_ms = round((time.time() - start) * 1000, 2)

    table.put_item(Item={
        "request_id": request_id,
        "tenant_id": x_tenant_id,
        "service": "generator",
        "model": "us.claude-sonnet-4-6",
        "latency_ms": int(latency_ms),
        "input_tokens": result["input_tokens"],
        "output_tokens": result["output_tokens"],
        "timestamp": int(time.time())
    })

    return GenerateResponse(
        generation=result["text"],
        request_id=request_id,
        latency_ms=latency_ms
    )
