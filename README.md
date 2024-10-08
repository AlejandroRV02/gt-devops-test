## GT DevOps Test

The purpose of this test is to deploy a 3 tier app: Frontend - Backend - Database

## Steps

- As the main step I took was to be able to run this application locally using Docker
I noticed this application was developed about 6 years ago, so I decided to use Node.js 14 image
I created two Dockerfiles, one for the frontend and one for the backend

Aditional to that, I use nginx to run frontend app made in Angular

- Secondly, I created a docker compose file to run both apps and the database
I found a problem related to a version of mongoose used in the backend, so I upgraded the package
For the database connection, I updated the config.json because I used Docker so I could use service name

Once everything was up I started working on the infrastructure

## Infrastructure

I used Terraform to have IaC. According to the requirements, I tried to manage everything in code.

## Futher steps

I created a deploy.sh script to do:

1. Create repositories in ECR
2. Create the images locally and push them to the repos
3. Run terraform to provision all the infrastructure and run the apps
4. Get the output needed, in this case a load balancer output