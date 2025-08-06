#!/usr/bin/env python3
"""Kickbase manager script

This script clones several GitHub repositories, installs their Python
requirements, and provides a small Tkinter GUI to launch each tool.
It also contains helper functions to download content from Kickly and
Kickbase dashboards.  The repositories are cloned inside
`/home/chillo/manager` as requested.

NOTE: Network access and valid credentials are required at runtime.
The login endpoints used in the download helpers are placeholders and
may need to be adapted to changes on the target sites.  Respect the
terms of service of every site you access.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tkinter as tk
from getpass import getpass
from pathlib import Path
from typing import Dict, List, Optional

import requests

REPOS: Dict[str, str] = {
    "don-botto": "https://github.com/WoodlegDev/don-botto",
    "kickbaseGiftCollector": "https://github.com/LukasFritz/kickbaseGiftCollector",
    "Kickbase-Insights": "https://github.com/casudo/Kickbase-Insights",
    "kickbase-AI": "https://github.com/Chillohillo/kickbase-AI",
}

BASE_DIR = Path("/home/chillo/manager")
REPO_DIR = BASE_DIR / "repos"


def clone_and_setup() -> None:
    """Clone repositories and install their requirements."""
    REPO_DIR.mkdir(parents=True, exist_ok=True)
    for name, url in REPOS.items():
        path = REPO_DIR / name
        if path.exists():
            subprocess.run(["git", "-C", str(path), "pull"], check=True)
        else:
            subprocess.run(["git", "clone", url, str(path)], check=True)
        install_requirements(path)


def install_requirements(path: Path) -> None:
    """Install Python requirements for a repository if present."""
    req = path / "requirements.txt"
    if req.exists():
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", str(req)], check=True)


def detect_command(path: Path) -> Optional[List[str]]:
    """Attempt to guess a command to run a repository."""
    candidates = ["main.py", "app.py", "run.py"]
    for candidate in candidates:
        if (path / candidate).exists():
            return [sys.executable, candidate]
    pkg_json = path / "package.json"
    if pkg_json.exists():
        return ["npm", "start"]
    return None


def run_repo(repo_name: str) -> None:
    path = REPO_DIR / repo_name
    command = detect_command(path)
    if not command:
        raise RuntimeError(f"No entry point found for {repo_name}.")
    subprocess.Popen(command, cwd=path)


def download_kickly(username: str, password: str) -> None:
    session = requests.Session()
    login_url = "https://www.kickly.de/login"
    data = {"email": username, "password": password}
    res = session.post(login_url, data=data)
    if res.status_code != 200:
        print("Kickly login failed.")
        return
    out = BASE_DIR / "kickly_data"
    out.mkdir(parents=True, exist_ok=True)
    home = session.get("https://www.kickly.de/")
    (out / "home.html").write_text(home.text, encoding="utf-8")
    print(f"Kickly data downloaded to {out}")


def download_kickbase(username: str, password: str) -> None:
    session = requests.Session()
    login_url = "https://kickbase.fabilous.tech/login"
    data = {"email": username, "password": password}
    res = session.post(login_url, data=data)
    if res.status_code != 200:
        print("Kickbase login failed.")
        return
    out = BASE_DIR / "kickbase_data"
    out.mkdir(parents=True, exist_ok=True)
    dashboard = session.get("https://kickbase.fabilous.tech/dashboard")
    (out / "dashboard.html").write_text(dashboard.text, encoding="utf-8")
    print(f"Kickbase data downloaded to {out}")


def prompt_and_download() -> None:
    user_k = input("Kickly username/email: ")
    pass_k = getpass("Kickly password: ")
    download_kickly(user_k, pass_k)
    user_b = input("Kickbase username/email: ")
    pass_b = getpass("Kickbase password: ")
    download_kickbase(user_b, pass_b)


def build_gui() -> None:
    root = tk.Tk()
    root.title("Kickbase Manager")

    tk.Label(root, text="Kickbase Tools").pack(pady=10)
    for repo in REPOS:
        frame = tk.Frame(root)
        frame.pack(pady=5)
        tk.Label(frame, text=repo).pack(side=tk.LEFT)
        tk.Button(frame, text="Run", command=lambda r=repo: run_repo(r)).pack(side=tk.LEFT, padx=5)
    tk.Button(root, text="Download Data", command=prompt_and_download).pack(pady=20)

    root.mainloop()


if __name__ == "__main__":
    clone_and_setup()
    build_gui()
