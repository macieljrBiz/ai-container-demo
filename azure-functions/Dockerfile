# Use Azure Functions Python base image
FROM mcr.microsoft.com/azure-functions/python:4-python3.11

# Set working directory
ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true

# Copy requirements and install dependencies
COPY requirements.txt /home/site/wwwroot/requirements.txt
RUN cd /home/site/wwwroot && \
    pip install --no-cache-dir -r requirements.txt

# Copy function app code
COPY . /home/site/wwwroot
