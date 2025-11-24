# AI Container Demo
Authors:    Andressa Siqueira - ansiqueira@microsoft.com & Vicente Maciel Jr - vicentem@microsoft.com

A FastAPI application demonstrating integration with Azure OpenAI using managed identity authentication.

## Features

- FastAPI web framework
- Azure OpenAI integration with token-based authentication
- Managed identity support via `azure-identity`
- REST API endpoint for AI responses

## Prerequisites

- Python 3.11 or higher
- Azure OpenAI resource with managed identity access configured
- Azure credentials configured (Azure CLI or managed identity)

## Installation

1. Create a virtual environment:
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

2. Install dependencies:
```powershell
pip install -r requirements.txt
```

## Configuration

The application uses the following Azure OpenAI configuration in `main.py`:

- **Endpoint**: `https://demos-airesource.openai.azure.com/`
- **Deployment**: `gpt-5.1`
- **Authentication**: Azure AD token provider with DefaultAzureCredential

Update these values in `main.py` to match your Azure OpenAI resource.

## Running the Application

Start the development server:
```powershell
uvicorn main:app --reload
```

The API will be available at `http://127.0.0.1:8000`

## API Endpoints

### GET /
Root endpoint returning a welcome message.

**Response:**
```json
{
  "message": "I'm Root!"
}
```

### POST /responses
Send a question to Azure OpenAI and receive a response.

**Request Body:**
```json
{
  "ask": "What is the capital of Brazil?"
}
```

**Response:**
```json
{
  "endpoint": "responses",
  "status": "success",
  "response": "..."
}
```

## Testing

Use the provided `test.http` file with the REST Client extension in VS Code, or use curl:

```powershell
# Test root endpoint
curl http://127.0.0.1:8000/

# Test responses endpoint
curl -X POST http://127.0.0.1:8000/responses -H "Content-Type: application/json" -d "{\"ask\":\"What is the capital of France?\"}"
```

## Interactive API Documentation

FastAPI provides automatic interactive API documentation:

- **Swagger UI**: http://127.0.0.1:8000/docs
- **ReDoc**: http://127.0.0.1:8000/redoc

## Dependencies

- `fastapi` - Modern web framework for building APIs
- `uvicorn` - ASGI server for running FastAPI applications
- `openai` - Azure OpenAI client library
- `azure-identity` - Azure authentication library
- `httpx` - HTTP client (required by openai library)
- `pydantic` - Data validation using Python type hints

## License

This is a demo application for educational purposes.
