# AI Foundry Setup Guide

This guide provides step-by-step instructions for setting up the required AI models in Azure AI Foundry for Flowspace, including Infrastructure as Code (IaC) templates using Bicep.

## Required Models

Flowspace requires two AI models for optimal functionality:

1. **Text Embedding Model**: `text-embedding-3-small` - For semantic code analysis and vector search
2. **Model Router**: Access to GPT models for intelligent content generation and summaries

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed and configured
- Access to Azure AI Foundry (https://ai.azure.com)
- Resource group for AI resources

## Manual Setup via Azure AI Foundry

### Step 1: Create AI Foundry Project

1. Navigate to [Azure AI Foundry](https://ai.azure.com)
2. Click "Create new project"
3. Configure project settings:
   - **Project name**: `flowspace-project`
   - **Subscription**: Select your subscription
   - **Resource group**: Create or select existing
   - **Location**: Choose appropriate region (e.g., East US, West Europe)

### Step 2: Deploy Text Embedding Model

1. In your AI Foundry project, go to **"Model catalog"**
2. Search for **"text-embedding-3-small"**
3. Click **"Deploy"**
4. Configure deployment:
   - **Deployment name**: `text-embedding-3-small`
   - **Model version**: Latest available
   - **Pricing tier**: Standard
   - **Tokens per minute rate limit**: 1M (adjust based on needs)
5. Click **"Deploy"**

### Step 3: Deploy Model Router

1. In the Model catalog, search for **"model-router"** or **"GPT-5"**
2. Deploy a model router or GPT model:
   - **Deployment name**: `model-router`
   - **Model**: model-router or your preferred model
   - **Version**: Latest available
   - **Pricing tier**: Standard
   - **Tokens per minute rate limit**: 1M (adjust based on needs)
3. Click **"Deploy"**

### Step 4: Get API Keys and Endpoints

1. Go to **"Deployments"** in your project
2. For each deployment, click **"View in playground"**
3. Note down:
   - **Endpoint URL** (e.g., `https://your-resource.openai.azure.com/`)
   - **API Key** (available in deployment details)
   - **Deployment names**


## Cost Optimization

- **Choose appropriate SKUs**: Start with Standard (S0) for development
- **Set rate limits**: Configure appropriate tokens per minute limits
- **Monitor usage**: Use Azure Cost Management to track spending
- **Regional considerations**: Some regions have lower costs for AI services

---

For more information, refer to the [Azure AI Foundry documentation](https://docs.microsoft.com/azure/ai-services/).
