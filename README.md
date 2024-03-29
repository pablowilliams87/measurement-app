# Measurement APP

## API
Measurement-app is an API written in Python, It uses SQLAlchemy as ORM to connect to Postgres Database. The API exposes the endpoint /air_quality to generate air quality measurements csv.

### App
```
app/
 |--> app.py --> Main code
 |--> models.py --> Object modeler
 |--> requirements.txt --> Python requirements
```

### Tools
```
tools/
 |--> build_docker_image.sh
 |--> 
```

### Docker

#### Build Docker Image
```bash
cd tools
./build_docker_image.sh <TAG>

Example: ./build_docker_image.sh measurement-app:1.2
```

#### Run Docker Image
```bash
docker run -d --name measurement-app -p 5000:5000 -e DB_URI=<postgres-db-uri> <image>
```

- `DB_URI` is an envvar that define postgres URI to connect to database. Example
```bash
DB_URI=postgresql://postgres:P0stgr3s@192.168.87.10:5432/environment_airq_measurand
```

#### Database
Not having a Postgres DB to test, the following command create a postgres container
```bash
# Option 1: Ephemeral postgres (Caution!! postgres data is not persistent)
docker run --name postgres-test -p 5432:5432 -e POSTGRES_PASSWORD=P0stgr3s -d postgres 

# Option 2: Persistent postgres
docker run --name postgres-test -p 5432:5432 -e POSTGRES_PASSWORD=P0stgr3s -v /datafiles/database/postgres:/var/lib/postgresql/data -d postgres 
```

#### Load Measurement data on DB
Create and load DB. It takes csv file from URL_MEASUREMENTS envvar (Default Value: https://gist.githubusercontent.com/jvillarf/040c91397d779d4da02fff54708ca935/raw/f1dbbcbfbc4e3daace7d907a3cc5b716ef808014/environment_airq_measurand.csv)
```bash
docker exec -ti measurement-app flask initdb
```

#### Test App
```bash
curl http://localhost:5000/air_quality
```

#### Push Docker Image
An example image was uploaded to Docker Hub using the following commands
```bash
docker tag measurement-app:1.2 pablowilliams87/measurement-app:1.2
docker push pablowilliams87/measurement-app:1.2
```

### Docker Compose

#### Deploy Compose
docker-compose definition includes the following services
- api: Docker container built with app/ code
- postgres: Postgresql DB with persistent data on /datafiles/database/postgresql

```bash
docker-compose up --build -d
```

#### [First Run] InitDB
```
docker exec -ti api-example_api_1 flask initdb
```

#### Delete Compose
```bash
docker-compose down
```



## CI (Continuous Integration)
### Infrastructure
*Cloud Provider*: Amazon

![infra](infrastructure/ecs_infra.png)

AWS hosts 3 VPC
- Production
- Staging
- Development

Each VPC hosts differents ECS Cluster to isolate environments. The infrastructure includes the creation of public and private subnets. Load Balancers are located in Public Subnet, API (ECS Cluster) and Databases are located in Private Subnet. As ECS Cluster needs to reach internet, NAT Gateways are deployed in Public Subnet. A Bastion Host is located in each public subnet to access to ECS instances.

About databases, Application uses Postgres RDS because It is scalable, easy to operate automating administrative tasks like backups and patching,
and it has read replication to improve platform availability.

All environments have an Application Load Balancer as ingress, Production has an Autoscaling Group with 4 instances as desired state (scale to 8 to duplicate its processing), Staging has 2 instances (Scaling to 4) and Development 1 instance.

Application uses SSM parameters to store sensitive data.


#### Terraform Configuration
```
infrastructure/<environment>/
 |--> ecr.tf            --> Container Registry
 |--> ecs.tf            --> ECS Cluster and Task Definition
 |--> iam.tf            --> Role Permissions
 |--> lb-asg.tf         --> Load Balancer, Auto Scaling Group, Launch Configuration
 |--> network.tf        --> VPC, Internet Gateway, NAT Gateway, Elastic IPs, Subnet, Route Tables, Bastion Host
 |--> outputs.tf        --> Terraform Outputs: Registry URL, Bastion Host IP, Load Balancer DNS
 |--> providers.tf      --> Terraform Provider
 |--> rds.tf            --> Database
 |--> ssm.tf            --> Sensitive data stored in SSM Parameter Store
 |--> variables.tf      --> Terraform variables
 |--> terraform.tfvars  --> Each environment has an example of tfvars with all available variables. It is not recommended to store this file in SCM but it was stored as an example
```


##### Applying TF configurations

- Configure AWS credentials
```bash
aws configure
```

- Edit tfvars files with apropriate configuration (default configuration could be used to test)

- Apply configuration
```bash
cd infrastructure/<environment>
terraform apply
```

- To initialize DB
```bash
cd infrastructure/<environment>
terraform apply -auto-approve -var="init_db=1" ; terraform apply -auto-approve -var="init_db=0"
```

- Access
```
http://<terraform_output_load_balancer_dns_name>/air_quality
```


### CI

To implement CI I choose GitHub Actions because is fully integrated with Github and does not require and external server/agent. To use it I have created GitHub actions pipelines in .github/workflows folder. Login to AWS account is through secrets configuration on GitHub account, once configured, they are instantiated from the pipeline
```
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
```

This project has the following pipelines
- A pull request to the main branch generates a Docker images, the image is pushes to AWS ECR and then it is deployed to Production ECS cluster.

[branch_production_pull_request.yml](.github/workflows/branch_production_pull_request.yml) 


- A pull request to the staging branch generates a Docker images, the image is pushes to AWS ECR and then it is deployed to Staging ECS cluster.

[branch_staging_pull_request.yml](.github/workflows/branch_staging_pull_request.yml)


- A pull request to the development branch generates a Docker images, the image is pushes to AWS ECR and then it is deployed to Development ECS cluster. 

[branch_development_pull_request.yml](.github/workflows/branch_development_pull_request.yml)




## Deployment
### DB
Creates a Kubernetes StatefulSet with 1 postgres's replica, creates a PersistentVolume to persist Database, and expose Postgres internally to Kubernetes Cluster using ClusterIP services. Through this services, API reaches DB via `postgres-svc.default.svc.cluster.local` endpoint
```bash
kubectl apply -f kubernetes/db.yml
```

### API Container
Creates a Kubernetes Deployment with 5 API container's replicas, and creates a service type ClusterIP to expose it internally.
```bash
kubectl apply -f kubernetes/api.yml

# Initialize measuremnts DB
kubectl exec -ti $(kubectl get pod | grep measurement-app | head -1 | awk '{ print $1 }') -- flask initdb
```

### Cache
Creates a Kubernetes deployment with 1 redis's replica, and creates a service type ClusterIP to expose it internally. Using this services API reaches redis-cache through the endpoint `redis-cache-svc.default.svc.cluster.local`
```bash
kubectl apply -f kubernetes/cache.yml
```
I chose redis as cache technology because 
- It permits to create a redis clusters to scale in case of application grows 
- It permits to insert redis keys with fixed TTL as invalidation strategy
- It permits to configure prefix keys to do partial cache clearing (e.g.: clear all keys with prefix XX)
- API framework (Flask) has a native integration using CACHE_TYPE redis


## Monitoring, Logs, Backups
### Monitoring
Prometheus Server will be used as backend to monitor the application and the infrastructure. Prometheus has an schema of pulling data (instead of Zabbix, Nagios or InfluxDB that they have agents to collect and send metrics to server) getting metrics from exporters, I have to deploy the following exporters
- node-exporter: It collects server metrics. CPU, Memory, Disk Usage, IO Statistics, NET Statistics, Uptime.
- flask-exporter: It collects metrics like Requests per Second, Requests duration, Resources usage (CPU, Memory).
- postgres-exporter: It collects DB metricsd

Grafana Server will be used as frontend monitoring service. Grafana will query prometheus as a data source, and shows metrics using different Dashboards (Server Metrics Dashboard, API Metrics Dashboard, Postgres Metrics Dashboard)

Prometheus Alert Manager will be used to send alerts notifications, configuring alerts rules based on thresholds. Alertmanager sends notification via Email, Slack, PagerDuty, and others.


### Logging
About logging we have two options:
- If we do not need to do real-time analysis of the data we can use rsyslog to collect logging data and send it to Rsyslog server.
- If we need to do real-time analysis we can use EFK Stack. Fluentd will be used as data collect, Elasticsearch as logging server. Kibana will be used as frontend, it permits to create dashbords and analize logs for detection of behavior patterns. It is useful to detect issues on application e.g. errors increments. 


### Backups
About backups, If the application uses Kubernetes, We can use Velero as Backups solution. Velero takes object definition snapshots and upload it to S3, or Minio. Minio is an Object Storage solution, S3 compatible.
