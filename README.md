

---

#  AI Content SaaS – Enterprise DevOps Implementation SOP- AWS Well-Architecured Framework

**Project Type:** Event-Driven SaaS Platform
**Cloud Provider:** AWS
**Architecture Style:** Decoupled, Asynchronous, Container-Based
**Deployment Model:** Infrastructure as Code + CI/CD
**Advanced Path:** Kubernetes (EKS) Migration

---

#  1. Architecture Overview

## ECS-Based Architecture (Initial Deployment)


![Image](https://d2908q01vomqb2.cloudfront.net/fc074d501302eb2b93e2554793fcaf50b3bf7291/2024/08/20/fig5-wesfarmers-queue-1024x482.png)

![Image](https://d2908q01vomqb2.cloudfront.net/fc074d501302eb2b93e2554793fcaf50b3bf7291/2021/12/13/Figure2-nmapWF.png)

![Image](https://d2908q01vomqb2.cloudfront.net/fc074d501302eb2b93e2554793fcaf50b3bf7291/2023/09/29/ITS-architecture-1024x483.png)

### Core Components

| Layer              | Service Used   |
| ------------------ | -------------- |
| Compute            | ECS Fargate    |
| Messaging          | SQS            |
| Storage            | S3             |
| Worker             | Lambda         |
| Container Registry | ECR            |
| Infrastructure     | Terraform      |
| CI/CD              | GitHub Actions |
| Observability      | CloudWatch     |

---

#  2. Repository Structure

```
ai-content-saas/
├── backend/                 # FastAPI backend
├── frontend/                # React frontend
├── infra/                   # Terraform IaC
├── helm/                    # Kubernetes Helm Chart
├── .github/workflows/       # CI/CD pipelines
└── docker-compose.yml       # Local testing
```

Separation of concerns:

* App code = `backend/`
* Infrastructure = `infra/`
* Deployment = `.github/workflows/`
* Kubernetes = `helm/`

---

#  3. Infrastructure Setup (Terraform – ECS Phase)

## Step 1: Initialize Terraform

```bash
cd infra
terraform init
terraform plan
terraform apply -auto-approve
```

### What This Creates

* VPC (isolated network)
* Subnets (Multi-AZ)
* ECR repository
* ECS Cluster
* Task Definition
* ECS Service
* S3 Bucket
* SQS Queue
* IAM Roles (Least Privilege)

 Entire infrastructure is reproducible with one command.

---

#  4. Backend Containerization

## Step 1: Dockerfile

```dockerfile
FROM python:3.10
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Step 2: Build and Push to ECR (Manual First Test)

```bash
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

docker build -t ai-saas-backend ./backend
docker tag ai-saas-backend:latest <ecr-url>:latest
docker push <ecr-url>:latest
```

---

# ⚙️ 5. ECS Deployment

Terraform creates:

* ECS Cluster
* Task Definition
* Service (Fargate)
* IAM Roles

Once deployed:

Visit:

```
http://<public-ip>:8000/docs
```

Health check should return:

```json
{
  "status": "healthy",
  "service": "content-engine"
}
```

---

#  6. Event-Driven Decoupling (The Senior Upgrade)

## Problem (Synchronous System)

API waits for AI processing → timeout → crash.

## Solution (Asynchronous Pattern)

### Flow

1. User uploads file
2. File stored in S3
3. SQS message created
4. API responds instantly
5. Lambda processes job in background

---

## Backend Upload Code

```python
s3_client.upload_fileobj(file.file, S3_BUCKET_NAME, file_key)

sqs_client.send_message(
    QueueUrl=SQS_QUEUE_URL,
    MessageBody=json.dumps({
        "file_key": file_key
    })
)
```

---

#  7. Lambda Worker (Serverless Processing)

## Worker Flow

1. Triggered by SQS
2. Reads message
3. Downloads file from S3
4. Processes with AI
5. Stores result

### Why Lambda?

* No idle servers
* Auto-scales instantly
* Pay per use
* Perfect for background jobs

---

#  8. Security Implementation

### IAM Least Privilege

* ECS Task Role:

  * Can access S3 (specific bucket only)
  * Can send message to SQS
  * Cannot access other AWS services

* Lambda Role:

  * Can read from SQS
  * Can read from S3
  * Nothing else

### Secrets

* Stored in GitHub Secrets
* Never hardcoded

---

#  9. CI/CD Automation (GitHub Actions)

## Trigger

On push to `main`

### Pipeline Flow

1. Checkout code
2. Authenticate with AWS
3. Build Docker image
4. Push to ECR
5. Update ECS Task Definition
6. Rolling deployment

Result:

```
Git Push → Live in 3 minutes
```

---

#  10. Observability (Day 2 Operations)

* CloudWatch Logs for ECS & Lambda
* Health check endpoint
* SQS Message visibility monitoring

Recommended Additions:

* CloudWatch Alarms
* SQS queue depth alarm
* CPU utilization alarm

---

#  11. Cost Optimization

* Fargate right-sized CPU
* Lambda for burst workloads
* SQS (free tier friendly)
* Single NAT Gateway

---

#  12. AWS Well-Architected Mapping

| Pillar                 | Implementation              |
| ---------------------- | --------------------------- |
| Operational Excellence | Terraform + CI/CD           |
| Security               | IAM Roles + Least Privilege |
| Reliability            | SQS Decoupling              |
| Performance            | Serverless Workers          |
| Cost                   | Pay-per-use                 |
| Sustainability         | Auto-scaling                |

---

#  13. Migration to Kubernetes (EKS)

## Why Migrate?

ECS is great.
Kubernetes is industry standard for large enterprises.

---

## EKS Architecture

![Image](https://d2908q01vomqb2.cloudfront.net/fc074d501302eb2b93e2554793fcaf50b3bf7291/2020/12/14/EKS-arhitecture-overview-1024x782.png)

![Image](https://kubernetes.io/images/docs/kubernetes-cluster-architecture.svg)

![Image](https://miro.medium.com/1%2AdV7Kec1af1Y1W250Z9FtIA.jpeg)

![Image](https://assets.cloudacademy.com/bakery/media/uploads/entity/blobid1-ed9f8e01-0402-4fcd-887f-25b8f50888f2.png)

---

## Step 1: Provision EKS with Terraform

```bash
terraform init
terraform apply -auto-approve
```

Creates:

* EKS Cluster
* Managed Node Group
* VPC
* Subnets
* NAT Gateway

---

## Step 2: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name ai-saas-cluster
```

Verify:

```bash
kubectl get nodes
```

---

#  14. Helm Deployment

## Structure

```
helm/
├── Chart.yaml
└── templates/
    ├── deployment.yaml
    └── service.yaml
```

## Deploy

```bash
helm install ai-saas ./helm
```

Now Kubernetes manages:

* Pods
* ReplicaSets
* Services
* Scaling

---

## Event-Based Autoscaling (KEDA)

Scale pods based on:

* SQS queue depth
* Not CPU

This saves massive cost.

---

## Observability Stack

Deploy:

* Prometheus
* Grafana

Get real-time dashboards for:

* Pod CPU
* Memory
* Latency
* Queue depth

---

#  16. Cleanup

```bash
terraform destroy -auto-approve
```

Stops billing immediately.

---<img width="1904" height="990" alt="Load balancer Multi -Az" src="https://github.com/user-attachments/assets/fa2b9b15-8c1a-4dff-a8d0-98c6691afdc6" />
<img width="1905" height="994" alt="S3 objects" src="https://github.com/user-attachments/assets/aab070eb-7f09-4e2f-968e-662306eeef64" />
<img width="1883" height="1002" alt="Auto sclae down" src="https://github.com/user-attachments/assets/13b2bd4d-bf98-4bdf-bd30-f4610d7fcd30" />
<img width="1890" height="993" alt="Cloud-watch" src="https://github.com/user-attachments/assets/f42c43b6-2080-4278-914d-f7f6195a51bb" />
<img width="1909" height="1070" alt="Vs Code" src="https://github.com/user-attachments/assets/d663cfc8-52a9-4c11-a926-339754ccf9b8" />
<img width="1917" height="991" alt="Auto scaling" src="https://github.com/user-attachments/assets/3b441784-496d-49c1-9f20-9adcb9559c6d" />
<img width="1899" height="981" alt="SQS" src="https://github.com/user-attachments/assets/afe61545-3f1c-47a0-bbc2-3f4be3cd1586" />


#  Final Result



* Decoupled architecture
* Container platform
* CI/CD automation
* Serverless background workers
* Infrastructure as Code
* Kubernetes migration
* Autoscaling
* Observability


