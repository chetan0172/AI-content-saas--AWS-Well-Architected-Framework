from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
import boto3
import os
import json
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="AI Content Repurposing Engine")

# --- CONFIGURATION (In Prod, these come from ENV) ---
# For now, hardcode them OR set them in the Dockerfile ENV
AWS_REGION = "us-east-1"
# REPLACE THESE WITH YOUR TERRAFORM OUTPUTS!
S3_BUCKET_NAME = "ai-saas-uploads-381584d9" 
SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/232048052422/ai-saas-jobs"

# Initialize Clients
s3_client = boto3.client('s3', region_name=AWS_REGION)
sqs_client = boto3.client('sqs', region_name=AWS_REGION)

@app.get("/")
def health_check():
    return {"status": "healthy", "service": "content-engine", "version": "v2.0"}

@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        file_key = file.filename
        
        # 1. Upload file to S3
        s3_client.upload_fileobj(file.file, S3_BUCKET_NAME, file_key)
        
        # 2. Send message to SQS
        message_body = {
            "file_key": file_key,
            "task": "generate_blog_post"
        }
        
        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message_body)
        )
        
        return {
            "message": "File uploaded and queued",
            "file": file_key,
            "queue_status": "Message sent to SQS"
        }
        
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))