"""Dual-Node LLM Inference Module

Orchestrates distributed LLM inference across local Windows node (11434 - RX 9070 XT)
and remote macOS node (11435) with automatic fallback.
"""

import sys
import argparse
import urllib.request
import json
import re

LOCAL_URL = "http://127.0.0.1:11434/api/generate"
MAC_URL = "http://localhost:11435/api/generate"
DEFAULT_MODEL = "qwen2.5-coder:14b"

def _query_endpoint(url: str, prompt: str, model: str = DEFAULT_MODEL, timeout: float = 90.0) -> str:
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False
    }).encode("utf-8")
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        data = json.loads(response.read().decode("utf-8"))
        return data.get("response", "")

async def delegate_inference_task(prompt: str, target_node: str = "auto", model: str = DEFAULT_MODEL) -> str:
    # Determine primary and fallback URLs
    is_code = bool(re.search(r"\b(def|class|function|local|luau|lua|código|code|Vector3|CFrame)\b", prompt, re.IGNORECASE))
    
    if target_node in ("mac_node", "mac") or (target_node == "auto" and is_code):
        primary_url = MAC_URL
        fallback_url = LOCAL_URL
        primary_name = "Mac Node (11435)"
        fallback_name = "Local Windows GPU RX 9070 XT (11434)"
    else:
        primary_url = LOCAL_URL
        fallback_url = MAC_URL
        primary_name = "Local Windows GPU RX 9070 XT (11434)"
        fallback_name = "Mac Node (11435)"

    try:
        return _query_endpoint(primary_url, prompt, model=model, timeout=90.0)
    except Exception as e:
        print(f"[DUAL-LLM] Primary endpoint {primary_name} failed ({e}), falling back to {fallback_name}...")
        try:
            return _query_endpoint(fallback_url, prompt, model=model, timeout=90.0)
        except Exception as fallback_e:
            return f"[DUAL-LLM ERROR] Both nodes failed. Error: {fallback_e}"

def run_sync(prompt: str, target_node: str = "auto", model: str = DEFAULT_MODEL) -> str:
    import asyncio
    return asyncio.run(delegate_inference_task(prompt, target_node=target_node, model=model))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Dual-Node LLM Inference CLI")
    parser.add_argument("--prompt", "-p", type=str, help="Prompt text")
    parser.add_argument("--target", "-t", type=str, default="auto", choices=["auto", "local", "gpu", "mac", "mac_node"], help="Target node")
    parser.add_argument("--model", "-m", type=str, default=DEFAULT_MODEL, help="Model name")
    parser.add_argument("positional_prompt", nargs="?", type=str, default=None, help="Positional prompt text")
    
    args = parser.parse_args()
    prompt_text = args.prompt or args.positional_prompt or "Explica brevemente la regla topológica de zonas en Roblox"
    
    result = run_sync(prompt_text, target_node=args.target, model=args.model)
    print(result)
