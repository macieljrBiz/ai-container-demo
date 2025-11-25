from fastapi import FastAPI
from openai import OpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from pydantic import BaseModel

endpoint = "https://demos-airesource.openai.azure.com/openai/v1/"
deployment_name = "gpt-5.1"
token_provider = get_bearer_token_provider(DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default")

client = OpenAI(
    base_url=endpoint,
    api_key=token_provider
)

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "I'm Root!"}

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
    return {"endpoint": "responses", "status": "success", "response": completion.choices[0].message.content}
