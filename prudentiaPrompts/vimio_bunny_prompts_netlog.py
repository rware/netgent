"""This example captures a Vimio visit scripted with NetGent. It opens the platform, spotlights login placeholders, and documents the steps for browsing without signing in.

Setup:
    1. Get a Gemini API key from https://aistudio.google.com/app/apikey
    2. Put it in a .env file (next to this script or in the project root) as:
           GOOGLE_API_KEY="your-key-here"
       or export it in your shell:
           export GOOGLE_API_KEY="your-key-here"
"""
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
WORKFLOW_PATH = "/home/rware/prudentia/netgent/prudentiaPrompts/vimio-bunny-results.json"

prompt = [
        StatePrompt(
            name="Begin Netlog",
            description="Enables netlog logging",
            triggers=["If it is on the current condition of the page! (Create trigger based on current page)"],
            actions=["[1] Press Ctrl+L (or Command+L on macOS) to focus the browser address bar", "[2] Type 'chrome://net-export' into the address bar", "[3] Press Enter to navigate to the site", "[4] Wait 5 seconds for the page to load", "[5] Click Start Logging to Disk", "[6] Save the file as vimioBunnyNetlog.json", "[7] Press control T (or comand T on mac os)"]
        ),

        StatePrompt(
            name="On Browser Home Page",
            description="Start the Process",
            triggers=["If it is on the current condition of the page! (Create trigger based on current page)"],
            actions=["[1] Press Ctrl+L (or Command+L on macOS) to focus the browser address bar", "[2] Type 'https://vimeo.com/1084537' into the address bar", "[3] Press Enter to navigate to the site", "[4] Wait 5 seconds for the page to load"]
        ),
        StatePrompt(
            name="On the Video Player",
            description="Play the video from the beginning for 600 seconds",
            triggers=["Only use URL as a Trigger"],
            actions=["[1] Click the Play button to start the video from the beginning", "[2] Wait 600 seconds while the video plays"]
        ),

        StatePrompt(
            name="End Netlog",
            description="Completes the Netlog session",
            triggers=["If it is on the current condition of the page! (Create trigger based on current page)"],
            actions=["[1] Press Ctrl+L (or Command+L on macOS) to focus the browser address bar", "[2] Type 'chrome://net-export' into the address bar", "[3] Press Enter to navigate to the site", "[4] Wait 5 seconds for the page to load", "[5] Click Stop Logging to Disk", "[6] Wait 5 seconds to ensure file is saved"],
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
