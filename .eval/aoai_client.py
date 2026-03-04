"""Async Azure OpenAI client using DefaultAzureCredential."""

import os

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from dotenv import load_dotenv
from openai import AsyncAzureOpenAI

load_dotenv()


async def get_aoai_client():
    token_provider = get_bearer_token_provider(
        DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
    )

    client = AsyncAzureOpenAI(
        base_url="https://workloads-assistant-aoai.openai.azure.com/openai/v1",
        api_version="preview",
        azure_ad_token_provider=token_provider,
    )

    return client
