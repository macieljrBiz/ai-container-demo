from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from openai import OpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from pydantic import BaseModel
import os

# Azure OpenAI Configuration with Managed Identity
endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "https://your-resource.cognitiveservices.azure.com/openai/v1/")
deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4")
token_provider = get_bearer_token_provider(
    DefaultAzureCredential(), 
    "https://cognitiveservices.azure.com/.default"
)

client = OpenAI(
    base_url=endpoint,
    api_key=token_provider
)

app = FastAPI()

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root():
    return FileResponse("static/index.html")

class AskRequest(BaseModel):
    ask: str

@app.post("/responses")
async def responses(request: AskRequest):
    completion = client.chat.completions.create(
        model=deployment_name,
        messages=[
            {
                "role": "user",
                "content": request.ask,
            }
        ]
    )
    return {
        "endpoint": "responses", 
        "status": "success", 
        "response": completion.choices[0].message.content
    }
