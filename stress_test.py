import requests
import concurrent.futures
import time
import random

# ================= CONFIGURATION =================
# REPLACE THIS with your Load Balancer DNS or Public IP
# Example: "http://54.123.45.67:8000"
API_URL = "http://18.204.202.103:8000"

# How many concurrent threads to run (Simulating users)
CONCURRENT_USERS = 50

# How many requests total to send
TOTAL_REQUESTS = 5000
# =================================================

def send_traffic(request_id):
    """
    Simulates a user uploading a file.
    """
    try:
        # 1. Generate a dummy file content
        filename = f"stress_test_{request_id}.txt"
        file_content = f"This is a stress test file number {request_id}."
        
        files = {
            'file': (filename, file_content, 'text/plain')
        }

        # 2. Hit the /upload endpoint (Stresses ECS + SQS)
        start_time = time.time()
        response = requests.post(f"{API_URL}/upload", files=files)
        duration = time.time() - start_time

        if response.status_code == 200:
            print(f"✅ [User {request_id % CONCURRENT_USERS}] Uploaded {filename} in {duration:.2f}s")
        else:
            print(f"❌ [User {request_id % CONCURRENT_USERS}] Failed: {response.status_code} - {response.text}")

    except Exception as e:
        print(f"🔥 Network Error: {e}")

print(f"🚀 Starting Stress Test on {API_URL} with {CONCURRENT_USERS} concurrent users...")
print("Check your CloudWatch Dashboard in 2-3 minutes!")

# Use a ThreadPool to simulate parallel users
with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENT_USERS) as executor:
    # Schedule the requests
    futures = [executor.submit(send_traffic, i) for i in range(TOTAL_REQUESTS)]
    
    # Wait for all to complete
    concurrent.futures.wait(futures)

print("🏁 Stress Test Complete.")