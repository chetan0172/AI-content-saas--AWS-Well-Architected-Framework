import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info("🚀 Worker started processing batch...")
    
    if 'Records' in event:
        for record in event['Records']:
            try:
                message_body = record['body']
                
                # --- GUARD CLAUSE: Handle empty messages ---
                if not message_body:
                    logger.warning("⚠️ Skipping empty message.")
                    continue

                # --- TRY PARSING ---
                try:
                    payload = json.loads(message_body)
                except json.JSONDecodeError:
                    logger.error(f"❌ Skipping invalid JSON message: {message_body}")
                    # We continue (do NOT raise) so SQS considers this message "done" and removes it.
                    continue
                
                # --- PROCESS VALID DATA ---
                file_key = payload.get('file_key', 'Unknown File')
                logger.info(f"📂 Processing file from S3: {file_key}")
                
                # Simulation Logic
                logger.info(f"✅ [SIMULATION] AI Content generated for {file_key}")

            except Exception as e:
                # If something ELSE fails (like S3 or OpenAI), we DO raise the error
                # so SQS retries it later. This is good behavior.
                logger.error(f"❌ System Error processing message: {str(e)}")
                raise e
                
    return {"status": "success"}