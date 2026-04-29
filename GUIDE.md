# CI/CD Pipeline Guide — Student Management System

### AUPP DevOps Final Project

---

## Files Created

```
.github/workflows/ci-cd.yml          ← GitHub Actions pipeline
sonar-project.properties             ← SonarCloud config
terraform/
  main.tf                            ← EC2 provisioning
  variables.tf
  outputs.tf
  user_data.sh                       ← Docker install on EC2
docker-compose.prod.yml              ← Production deploy (pulls from DockerHub)
monitoring/
  prometheus.yml                     ← Scrape config
  docker-compose.monitoring.yml      ← Prometheus + Grafana + Node Exporter
```

---

## Pipeline Flow

```
Push to main
    │
    ▼
1 · SonarCloud Quality Scan   ──── FAIL → pipeline stops
    │
    ▼
2 · Trivy Security Scan       ──── FAIL (CRITICAL CVE) → pipeline stops
    │
    ▼
3 · Build & Push Docker Images → Docker Hub
    │
    ▼
4 · Terraform Provision EC2   → AWS
    │
    ▼
5 · Deploy to EC2 via SSH     → live app + monitoring
```

---

## Required Screenshots Checklist

| # | Screenshot                               | Where to get it                 |
| - | ---------------------------------------- | ------------------------------- |
| a | GitHub branches + PR                     | GitHub → Pull Requests         |
| b | Reviewer approval                        | PR page → Approvals tab        |
| c | Merge conflict markers + resolved file   | VS Code or GitHub diff view     |
| d | Full CI/CD workflow file                 | `.github/workflows/ci-cd.yml` |
| e | SonarCloud report                        | sonarcloud.io → your project   |
| f | Trivy scan output                        | GitHub Actions → Job 2 logs    |
| g | Pipeline stopped at quality gate failure | GitHub Actions → Job 1 failed  |
| h | Terraform plan/apply output              | GitHub Actions → Job 4 logs    |
| i | Continuous deployment SSH output         | GitHub Actions → Job 5 logs    |
| j | All 5 jobs green (graphical view)        | GitHub Actions → workflow run  |
| k | Browser showing running app on EC2 IP    | `http://<EC2_IP>:5000`        |
| l | Grafana dashboard with live metrics      | `http://<EC2_IP>:3000`        |

---

## PHASE 1 — GitHub Setup

### Step 1.1 — Enable Branch Protection

1. Go to your GitHub repo → **Settings → Branches**
2. Click **Add branch protection rule**
3. Branch name pattern: `main`
4. Enable:
   - Require a pull request before merging
   - Require approvals → **1**
   - Require status checks to pass (add `sonarcloud`, `trivy`, `build-push` after first run)
5. Click **Save changes**

> Screenshot needed: Branch protection rules page

---

### Step 1.2 — Add a Reviewer

1. Go to repo → **Settings → Collaborators → Add peoplez**
2. Add a classmate's GitHub username
3. They must accept the invitation email

---

### Step 1.3 — Create and Resolve a Merge Conflict

This simulates two developers editing the same file at the same tizme.

**Developer A — create a feature branch:**

```bash
git checkout -b feature/grading-update

# Edit conflictTest.js — change the line to:
# console.log("Feature branch: grading API updated.");

git add conflictTest.js
git commit -m "feature: update grading API message"
git push origin feature/grading-update
```

**Developer B — edit the same file on main:**

```bash
git checkout main

# Edit conflictTest.js — change the line to:
# console.log("Main branch: hotfix applied to grading.");

git add conflictTest.js
git commit -m "hotfix: grading fix on main"
git push origin main
```

**Create a Pull Request on GitHub:**

1. GitHub → **Pull Requests → New pull request**
2. Base: `main` ← Compare: `feature/grading-update`
3. Assign the classmate as reviewer
4. GitHub will show a **conflict warning**

> Screenshot needed: PR page showing conflict warning

**Resolve the conflict locally:**

```bash
git checkout feature/grading-update
git merge main

# conflictTest.js now looks like:
# <<<<<<< HEAD
# console.log("Feature branch: grading API updated.");
# =======
# console.log("Main branch: hotfix applied to grading.");
# >>>>>>> main

# Edit the file — delete the conflict markers and keep the merged version:
# console.log("Merged: grading API updated with hotfix.");

git add conflictTest.js
git commit -m "resolve: merge conflict in conflictTest.js"
git push origin feature/grading-update
```

> Screenshot needed: conflict markers in editor, then the resolved file

**Reviewer approves the PR on GitHub → click Merge pull request**

> Screenshot needed: reviewer approval, merged PR

---

## PHASE 2 — SonarCloud Setup

### Step 2.1 — Create Account

1. Go to [sonarcloud.io](https://sonarcloud.io)
2. Click **Log in with GitHub**
3. Click **+** → **Analyze new project** → select your repo
4. Note your **Organization key** and **Project key**

### Step 2.2 — Update sonar-project.properties

Open `sonar-project.properties` and replace the placeholders:

```properties
sonar.projectKey=chanhengmenh_student-management-system
sonar.organization=chanhengmenh
```

Example (if GitHub username is `menh`):

```properties
sonar.projectKey=menh_student-management-system
sonar.organization=menh
```

### Step 2.3 — Get SonarCloud Token

1. SonarCloud → **My Account → Security → Generate Token**
2. Name it `github-actions`
3. Copy the token — you will add it to GitHub Secrets

### Step 2.4 — Demo Quality Gate Failure (screenshot g)

To capture the pipeline stopping due to a failed quality gate:

1. SonarCloud → **Project → Administration → Quality Gates**
2. Create a custom gate condition, e.g. **Coverage < 80%** or **Bugs > 0**
3. Push any commit → Job 1 fails → Jobs 2–5 never run
4. Take the screenshot
5. Restore the gate back to **Sonar way** (default)

---

## PHASE 3 — Docker Hub Setup

1. Create an account at [hub.docker.com](https://hub.docker.com)
2. Go to **Account Settings → Security → New Access Token**
3. Name it `github-actions`
4. Copy the token

Your Docker images will be pushed as:

```
<your-username>/sms-gateway:latest
<your-username>/sms-add:latest
<your-username>/sms-delete:latest
<your-username>/sms-update:latest
<your-username>/sms-search:latest
```

---

## PHASE 4 — AWS Setup

### Step 4.1 — Create IAM User

1. AWS Console → **IAM → Users → Create user**
2. Name: `sms-deploy`
3. Attach permissions: **AmazonEC2FullAccess** + **AmazonS3FullAccess**
4. Create access key → download **Access Key ID** and **Secret Access Key**

### Step 4.2 — Generate SSH Key Pair (on your laptop)

Run in Git Bash or terminal:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/sms-deploy-key -N ""
```

This creates two files:

- `~/.ssh/sms-deploy-key` → private key (keep secret, goes to GitHub Secrets)
- `~/.ssh/sms-deploy-key.pub` → public key (goes to GitHub Secrets)

View them:

```bash
cat ~/.ssh/sms-deploy-key.pub   # EC2_PUBLIC_KEY secret
cat ~/.ssh/sms-deploy-key       # EC2_SSH_KEY secret
```

### Step 4.3 — Create S3 Bucket for Terraform State

This bucket stores the Terraform state file so every pipeline run knows what EC2 already exists.

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region: us-east-1, output: json

aws s3 mb s3://aupp-sms-tfstate --region us-east-1
```

> Only run this once. The bucket name must match `terraform/main.tf` → `backend "s3" { bucket = "aupp-sms-tfstate" }`

---

## PHASE 5 — GitHub Secrets

Go to repo → **Settings → Secrets and variables → Actions → New repository secret**

Add all 8 secrets:

| Secret Name               | Value                                          |
| ------------------------- | ---------------------------------------------- |
| `SONAR_TOKEN`           | Token from SonarCloud                          |
| `DOCKERHUB_USERNAME`    | Your Docker Hub username                       |
| `DOCKERHUB_TOKEN`       | Docker Hub access token                        |
| `AWS_ACCESS_KEY_ID`     | IAM user access key                            |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key                            |
| `AWS_REGION`            | `us-east-1`                                  |
| `EC2_PUBLIC_KEY`        | Full contents of `~/.ssh/sms-deploy-key.pub` |
| `EC2_SSH_KEY`           | Full contents of `~/.ssh/sms-deploy-key`     |

---

## PHASE 6 — First Pipeline Run

### Step 6.1 — Push Everything to main

```bash
git add .github/ sonar-project.properties terraform/ docker-compose.prod.yml monitoring/
git commit -m "ci: add complete CI/CD pipeline with monitoring"
git push origin main
```

### Step 6.2 — Watch the Pipeline

Go to GitHub repo → **Actions** tab → click the running workflow

The 5 jobs run in sequence:

```
1 · SonarCloud Quality Scan    ✅
2 · Trivy Security Scan        ✅
3 · Build & Push Docker Images ✅
4 · Terraform Provision EC2    ✅
5 · Deploy to EC2              ✅
```

> Screenshot needed: all 5 jobs green (graphical view in Actions tab)

### Step 6.3 — Get Your EC2 IP

In the Actions tab → click Job 4 (Terraform Provision EC2) → expand **Get EC2 public IP** step → copy the IP address.

Or from your terminal:

```bash
cd terraform
terraform output ec2_public_ip
```

---

## PHASE 7 — Access Your Application

Open in your browser:

```
http://<EC2_IP>:5000
```

Should display: `✅ API Gateway is running...`

Test with curl from your laptop:

```bash
# Health check
curl http://<EC2_IP>:5000

# Add a student
curl -X POST http://<EC2_IP>:5000/add \
  -H "Content-Type: application/json" \
  -d '{"ID":"S001","Name":"Chan Heng","Age":20,"Class":"CS401"}'

# Search all students
curl http://<EC2_IP>:5000/search
```

> Screenshot needed: browser showing the running application

---

## PHASE 8 — Grafana Dashboard

### Step 8.1 — Open Grafana

```
http://<EC2_IP>:3000
Username: admin
Password: admin123
```

### Step 8.2 — Add Prometheus Data Source

1. Grafana left sidebar → **Connections → Data sources**
2. Click **Add data source** → choose **Prometheus**
3. URL: `http://prometheus:9090`
4. Click **Save & Test** → should say "Successfully queried the Prometheus API"

### Step 8.3 — Import Node Exporter Dashboard

1. Grafana left sidebar → **Dashboards → Import**
2. Enter dashboard ID: **`1860`** (Node Exporter Full)
3. Click **Load**
4. Select your Prometheus data source
5. Click **Import**

You will immediately see live metrics from your EC2 instance:

- CPU usage %
- Memory usage
- Disk I/O
- Network traffic

> Screenshot needed: Grafana dashboard showing live metrics

---

## Troubleshooting

**Pipeline fails at Terraform — key pair already exists**

```bash
# Import the existing key pair into Terraform state:
cd terraform
terraform import aws_key_pair.sms_key sms-deploy-key
```

**Cannot SSH into EC2 after deploy**

```bash
# Test SSH manually from your laptop:
ssh -i ~/.ssh/sms-deploy-key ubuntu@<EC2_IP>

# If connection times out, check security group in AWS Console
# → EC2 → Security Groups → sms-security-group → Inbound rules
# Port 22 must allow 0.0.0.0/0
```

**Monitoring stack cannot find app network**

```bash
# SSH into EC2, check Docker networks:
ssh -i ~/.ssh/sms-deploy-key ubuntu@<EC2_IP>
docker network ls
# Should see: sms_sms-network
# If missing, restart app stack first:
docker compose -p sms -f /home/ubuntu/app/docker-compose.prod.yml up -d
```

**Grafana shows "No data"**

1. Verify Prometheus is scraping: `http://<EC2_IP>:9090/targets`
2. All targets should show **State: UP**
3. If node-exporter shows DOWN, check the monitoring compose is running:
   ```bash
   docker ps | grep node-exporter
   ```
