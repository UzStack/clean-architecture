# DevOps & CI/CD - Avtomatlashtirish

DevOps - bu development va operations'ni birlashtiruvchi madaniyat.

---

## CI/CD nima?

**CI (Continuous Integration):**
- Kodlarni tez-tez merge qilish
- Avtomatik test
- Avtomatik build

**CD (Continuous Delivery/Deployment):**
- Avtomatik deployment
- Production'ga tez yetkazish
- Manual approval (Delivery)
- Auto deploy (Deployment)

```
Code → Build → Test → Deploy
  ↓       ↓       ↓       ↓
 Git   Docker   Unit   Production
       Build    Tests
```

---

## Git Workflow

### Git Flow

```
main (production)
  ↓
develop (development)
  ↓
feature/new-feature
  ↓
develop
  ↓
release/v1.0.0
  ↓
main + develop
```

```bash
# Feature branch yaratish
git checkout -b feature/user-authentication

# Kod yozish
git add .
git commit -m "feat: add user authentication"

# Develop'ga merge qilish
git checkout develop
git merge feature/user-authentication

# Release yaratish
git checkout -b release/v1.0.0

# Main'ga merge
git checkout main
git merge release/v1.0.0
git tag v1.0.0
```

### Commit Messages (Conventional Commits)

```bash
# Format: <type>(<scope>): <subject>

git commit -m "feat(auth): add JWT authentication"
git commit -m "fix(api): resolve null reference exception"
git commit -m "docs(readme): update installation guide"
git commit -m "refactor(service): simplify order processing"
git commit -m "test(user): add unit tests for user service"
git commit -m "chore(deps): update package versions"

# Breaking change
git commit -m "feat(api)!: change authentication endpoint"
```

**Types:**
- `feat`: Yangi feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (formatting)
- `refactor`: Code refactoring
- `test`: Tests
- `chore`: Maintenance
- `perf`: Performance improvement

---

## GitHub Actions

### Basic Workflow

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: '7.0.x'
    
    - name: Restore dependencies
      run: dotnet restore
    
    - name: Build
      run: dotnet build --no-restore --configuration Release
    
    - name: Run tests
      run: dotnet test --no-build --verbosity normal --configuration Release
    
    - name: Code coverage
      run: dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.cobertura.xml
```

### Advanced Workflow with Docker

```yaml
# .github/workflows/docker-publish.yml
name: Docker Build & Push

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

env:
  REGISTRY: docker.io
  IMAGE_NAME: mycompany/myapp

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
    - name: Checkout
      uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
```

### Multi-Environment Deployment

```yaml
# .github/workflows/deploy.yml
name: Deploy to Environments

on:
  push:
    branches:
      - develop  # Deploy to staging
      - main     # Deploy to production

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
    - name: Deploy to staging
      run: |
        echo "Deploying to staging..."
        # kubectl apply -f k8s/staging/
        # or helm upgrade --install
  
  deploy-production:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    
    steps:
    - name: Deploy to production
      run: |
        echo "Deploying to production..."
        # Blue-Green or Canary deployment
```

---

## Docker

### Dockerfile Best Practices

```dockerfile
# Multi-stage build
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Copy csproj and restore (caching layer)
COPY ["MyApp/MyApp.csproj", "MyApp/"]
RUN dotnet restore "MyApp/MyApp.csproj"

# Copy everything else and build
COPY . .
WORKDIR "/src/MyApp"
RUN dotnet build "MyApp.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "MyApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Final stage - runtime only
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS final
WORKDIR /app

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

COPY --from=publish /app/publish .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:80/health || exit 1

EXPOSE 80
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "5000:80"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__DefaultConnection=Server=db;Database=myapp;User=sa;Password=YourStrong@Passw0rd
    depends_on:
      - db
      - redis
    networks:
      - app-network
    restart: unless-stopped
  
  db:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=YourStrong@Passw0rd
    ports:
      - "1433:1433"
    volumes:
      - sqldata:/var/opt/mssql
    networks:
      - app-network
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data
    networks:
      - app-network
  
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - api
    networks:
      - app-network

volumes:
  sqldata:
  redisdata:

networks:
  app-network:
    driver: bridge
```

---

## Kubernetes (K8s)

### Deployment

```yaml
# deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: mycompany/myapp:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        - name: ConnectionStrings__DefaultConnection
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: connection-string
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

### ConfigMap & Secrets

```yaml
# configmap.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
data:
  appsettings.json: |
    {
      "Logging": {
        "LogLevel": {
          "Default": "Information"
        }
      }
    }
---
# secrets.yml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
type: Opaque
data:
  connection-string: U2VydmVyPW15c3FsO0RhdGFiYXNlPW15YXBwOw== # base64 encoded
  api-key: bXktc2VjcmV0LWFwaS1rZXk=
```

### Horizontal Pod Autoscaler

```yaml
# hpa.yml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Monitoring & Logging

### Prometheus & Grafana

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'myapp'
    static_configs:
      - targets: ['myapp:80']
    metrics_path: '/metrics'
```

```csharp
// ASP.NET Core Metrics
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddPrometheusMetrics();
    }
    
    public void Configure(IApplicationBuilder app)
    {
        app.UseMetricServer(); // /metrics endpoint
        app.UseHttpMetrics();  // HTTP request metrics
    }
}

// Custom metrics
public class OrderService
{
    private static readonly Counter OrdersCreated = Metrics
        .CreateCounter("orders_created_total", "Total orders created");
    
    private static readonly Histogram OrderProcessingDuration = Metrics
        .CreateHistogram("order_processing_duration_seconds", "Order processing duration");
    
    public async Task<Order> CreateOrderAsync(Order order)
    {
        using (OrderProcessingDuration.NewTimer())
        {
            var result = await _repository.AddAsync(order);
            OrdersCreated.Inc();
            return result;
        }
    }
}
```

### ELK Stack (Elasticsearch, Logstash, Kibana)

```csharp
// Serilog with ELK
public class Program
{
    public static void Main(string[] args)
    {
        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .Enrich.FromLogContext()
            .Enrich.WithMachineName()
            .Enrich.WithEnvironmentName()
            .WriteTo.Console()
            .WriteTo.Elasticsearch(new ElasticsearchSinkOptions(
                new Uri("http://elasticsearch:9200"))
            {
                AutoRegisterTemplate = true,
                IndexFormat = "myapp-logs-{0:yyyy.MM.dd}"
            })
            .CreateLogger();
        
        CreateHostBuilder(args).Build().Run();
    }
}
```

---

## Infrastructure as Code (IaC)

### Terraform

```hcl
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "myapp-vpc"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "myapp-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "myapp"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "256"
  memory                  = "512"
  
  container_definitions = jsonencode([
    {
      name  = "myapp"
      image = "mycompany/myapp:latest"
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "ASPNETCORE_ENVIRONMENT"
          value = "Production"
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "myapp-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 3
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.app.id]
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "myapp"
    container_port   = 80
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "myapp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = aws_subnet.public[*].id
}
```

### Ansible

```yaml
# playbook.yml
---
- name: Deploy Application
  hosts: webservers
  become: yes
  
  vars:
    app_name: myapp
    app_version: "1.0.0"
  
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
    
    - name: Install Docker
      apt:
        name: docker.io
        state: present
    
    - name: Pull Docker image
      docker_image:
        name: "{{ app_name }}:{{ app_version }}"
        source: pull
    
    - name: Stop old container
      docker_container:
        name: "{{ app_name }}"
        state: stopped
      ignore_errors: yes
    
    - name: Remove old container
      docker_container:
        name: "{{ app_name }}"
        state: absent
      ignore_errors: yes
    
    - name: Run new container
      docker_container:
        name: "{{ app_name }}"
        image: "{{ app_name }}:{{ app_version }}"
        state: started
        ports:
          - "80:80"
        env:
          ASPNETCORE_ENVIRONMENT: Production
        restart_policy: unless-stopped
```

---

## Deployment Strategies

### Blue-Green Deployment

```yaml
# Blue environment (current production)
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
    version: blue  # Current version
---
# Green environment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0  # New version

# Switch traffic to green:
# kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"green"}}}'
```

### Canary Deployment

```yaml
# 90% traffic to stable version
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
      version: stable
---
# 10% traffic to canary version
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: canary
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0  # New version
---
# Service (selects both)
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp  # Matches both stable and canary
```

---

## Backup & Disaster Recovery

```bash
# Database backup script
#!/bin/bash

DB_NAME="myapp"
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="$BACKUP_DIR/${DB_NAME}_${DATE}.sql"

# Backup
docker exec mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} $DB_NAME > $FILENAME

# Compress
gzip $FILENAME

# Upload to S3
aws s3 cp ${FILENAME}.gz s3://my-backups/database/

# Delete old backups (keep last 7 days)
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

echo "Backup completed: ${FILENAME}.gz"
```

```yaml
# Kubernetes CronJob for backups
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
spec:
  schedule: "0 2 * * *"  # Every day at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: mysql:8
            command:
            - /bin/sh
            - -c
            - |
              mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME | \
              gzip > /backup/backup_$(date +%Y%m%d_%H%M%S).sql.gz
            env:
            - name: DB_HOST
              value: "mysql-service"
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: username
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-volume
            persistentVolumeClaim:
              claimName: backup-pvc
```

---

## DevOps Best Practices

### 1. Automation
- ✅ Har bir jarayonni avtomatlashtiring
- ✅ Manual deployment yo'q
- ✅ Infrastructure as Code

### 2. Monitoring
- ✅ Har bir service monitoring qilingan
- ✅ Alertlar sozlangan
- ✅ Dashboards mavjud

### 3. Security
- ✅ Secrets management (Vault, AWS Secrets Manager)
- ✅ Image scanning
- ✅ Least privilege access

### 4. Testing
- ✅ Automated tests
- ✅ Integration tests
- ✅ Smoke tests after deployment

### 5. Documentation
- ✅ Runbooks
- ✅ Architecture diagrams
- ✅ Deployment procedures

---

## DevOps Roadmap

### Level 1: Beginner
- [ ] Git basics
- [ ] Docker basics
- [ ] CI/CD concepts
- [ ] Linux commands

### Level 2: Intermediate
- [ ] GitHub Actions / GitLab CI
- [ ] Docker Compose
- [ ] Kubernetes basics
- [ ] Terraform basics

### Level 3: Advanced
- [ ] Kubernetes advanced (Helm, Operators)
- [ ] Multi-cloud (AWS, Azure, GCP)
- [ ] Service Mesh (Istio)
- [ ] GitOps (ArgoCD, Flux)

---

## Keyingi Qadamlar

DevOps asoslarini o'rgandingiz! Endi:

1. **Soft Skills** - Leadership, Communication
2. **Architecture Patterns** - Microservices, Event-Driven
3. **Career Development** - Interview prep, Portfolio

**Mashq:** O'z loyihangizga CI/CD pipeline qo'shing va Kubernetes'ga deploy qiling!

Keyingi: [Soft Skills for Senior Developers](./10-soft-skills.md)
