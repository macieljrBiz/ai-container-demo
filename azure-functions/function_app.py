import azure.functions as func
import logging
import json
import os
from openai import OpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

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

@app.route(route="responses", methods=["POST"])
def chat_endpoint(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Processing chat request')

    try:
        req_body = req.get_json()
        logging.info(f'Request body: {req_body}')
        user_input = req_body.get('ask')

        if not user_input:
            return func.HttpResponse(
                json.dumps({"error": "Field 'ask' is required"}),
                status_code=400,
                mimetype="application/json"
            )

        # Azure OpenAI call
        logging.info(f'Calling Azure OpenAI with input: {user_input}')
        completion = client.chat.completions.create(
            model=deployment_name,
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": user_input}
            ]
        )

        response_text = completion.choices[0].message.content
        logging.info('Successfully got response from OpenAI')

        return func.HttpResponse(
            json.dumps({"response": response_text}),
            status_code=200,
            mimetype="application/json"
        )

    except ValueError as e:
        logging.error(f"ValueError: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Invalid JSON"}),
            status_code=400,
            mimetype="application/json"
        )
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        logging.error(f"Error: {str(e)}")
        logging.error(f"Traceback: {error_details}")
        return func.HttpResponse(
            json.dumps({"error": str(e), "details": error_details}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="index", methods=["GET"])
def index(req: func.HttpRequest) -> func.HttpResponse:
    """Serve static HTML page"""
    logging.info('Serving index page')
    
    try:
        base_path = os.path.dirname(os.path.abspath(__file__))
        html_path = os.path.join(base_path, 'static', 'index.html')
        
        with open(html_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
        
        return func.HttpResponse(
            html_content,
            status_code=200,
            mimetype="text/html"
        )
    except FileNotFoundError:
        return func.HttpResponse(
            "<h1>AI Chat Interface</h1><p>Static files not found. Use /api/responses endpoint for API access.</p>",
            status_code=200,
            mimetype="text/html"
        )
