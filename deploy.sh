#!/bin/bash

# Exit script on any error
set -e

echo "Initializing Node.js project..."
npm init -y  # Initialize package.json if not already present

echo "Installing required dependencies..."
npm install mongodb dotenv

echo "Packaging Lambda function..."
zip -r lambda.zip index.js node_modules package.json

echo "Initializing Terraform..."
terraform init

echo "Applying Terraform configuration..."
terraform apply -auto-approve

echo "Deployment completed successfully! 🚀"
