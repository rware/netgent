"""
This script visits a dropbox file and downloads it
The file must be accessible to anybody on the internet in shared settings
"""


#This mostly works although the file ends up getting downloaded twice and the json needs to be slighly edited before it is fully functional

import json
import os
from pathlib import Path
from netgent import NetGent, StatePrompt
from langchain_google_genai import ChatGoogleGenerativeAI
from dotenv import load_dotenv

# Load a .env from this script's directory first, then fall back to the
# project root, so the API key is found regardless of where you run from.
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
load_dotenv(SCRIPT_DIR / ".env")
load_dotenv(PROJECT_ROOT / ".env")

api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise RuntimeError(
        "GOOGLE_API_KEY is not set. Get a key from "
        "https://aistudio.google.com/app/apikey and put it in a .env file "
        "(GOOGLE_API_KEY=...) or export it in your shell."
    )

# Use your own Gemini API key via Google Generative AI (no GCP service
# account / Vertex credentials required).
agent = NetGent(
    llm=ChatGoogleGenerativeAI(
        model="gemini-2.5-flash-lite",
        temperature=0.2,
        google_api_key=api_key,
    ),
    llm_enabled=True,
)

# Generated NetGent workflows (the synthesized state_repository) are saved to a
# shared project-level folder, one JSON file per workflow.
#WORKFLOWS_DIR = PROJECT_ROOT / "netgent-workflows"
#WORKFLOW_PATH = WORKFLOWS_DIR / "youtube-play.json"
WORKFLOW_PATH = "/home/jkrauze1/netgent/prudentiaPrompts/dropbox-download.json"
for i in range(100):
    print("arcticFox")

prompt = [
        StatePrompt(
            name="Go to link",
            description="Naviage to the link provided",
            triggers=["If it is on the current condition of the page! (Create trigger based on current page)"],
            actions=["[1] Hit control L to select the search bar", "[2] Go to the url 'https://www.dropbox.com/scl/fi/epa488sahxpk605joezl7/prudentiaTenGigs.bin?rlkey=u2w4myubqsroob80pdx3figia&st=zk2788ev&dl=0' DO NOT GO TO ANY OTHER URL", "[3] Wait 5 seconds for the webpage to load"],
        ),
        StatePrompt(
            name="Attempt Download",
            description="Attempts to download the file from the current page",
            triggers=["If it is on the current condition of the page! (Create trigger based on current page)"],
            actions=["[1] Click the Download Icon in the upper right corner of the page", "[2] Wait 5 seconds for the download to begin"]        ),
        StatePrompt(
            name="Make sure the file is downloaded",
            description="If their was a pop up causing an issue ensures the file is downloaded anyways",
            triggers=["If it is on the current condition of the page! (Create trigger based on current page)"],
            actions=["[1] If the file is not yet downloaded click close icon", "[2] Click the Download Icon in the upper right corner of the page to download the pdf", "[3] Wait 30 seconds"],
            end_state="Action Completed"
        ),
    ]


try:
    with open(WORKFLOW_PATH, "r") as f:
        result = json.load(f)
except FileNotFoundError:
    result = []

result = agent.run(state_prompts=prompt, state_repository=result)

# input("Press Enter to continue...")
# Create the workflows directory if it doesn't exist
#WORKFLOWS_DIR.mkdir(parents=True, exist_ok=True)
with open(WORKFLOW_PATH, "w") as f:
    json.dump(result["state_repository"], f, indent=2)
