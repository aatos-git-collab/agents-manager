#!/usr/bin/env python3
"""
Git Project Manager
Manages git projects with structure awareness.
"""

import subprocess
import os
import json
import hashlib
from datetime import datetime
from pathlib import Path

class GitProjectManager:
    def __init__(self, project_root=None):
        self.project_root = project_root or os.getcwd()
        selfbrains_repo = "git@github.com:aatosai/brains.git"  # Agent brains backup
        
    def detect_structure(self, project_path):
        """Detect project structure and language."""
        structure = {
            "files": [],
            "directories": [],
            "language": None,
            "has_git": False,
            "has_docker": False,
            "has_package_json": False,
            "has_requirements": False,
            "has_go_mod": False,
        }
        
        for root, dirs, files in os.walk(project_path):
            # Skip hidden and git folders
            dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'node_modules']
            
            for f in files:
                path = os.path.join(root, f)
                rel_path = os.path.relpath(path, project_path)
                structure["files"].append(rel_path)
                
                # Detect language/framework
                if f == "package.json":
                    structure["has_package_json"] = True
                    structure["language"] = "node"
                elif f == "requirements.txt":
                    structure["has_requirements"] = True
                    structure["language"] = "python"
                elif f == "go.mod":
                    structure["has_go_mod"] = True
                    structure["language"] = "go"
                elif f == "Dockerfile" or f == "docker-compose.yml":
                    structure["has_docker"] = True
                    
            for d in dirs:
                structure["directories"].append(d)
                
        structure["total_files"] = len(structure["files"])
        structure["total_dirs"] = len(structure["directories"])
        
        return structure
    
    def analyze_git_status(self, project_path):
        """Analyze git status and branches."""
        os.chdir(project_path)
        
        # Get current branch
        branch = subprocess.run(["git", "branch", "--show-current"], 
                              capture_output=True, text=True).stdout.strip()
        
        # Get recent commits
        commits = subprocess.run(["git", "log", "--oneline", "-10"], 
                               capture_output=True, text=True).stdout.strip().split('\n')
        
        # Get remote
        remote = subprocess.run(["git", "remote", "get-url", "origin"], 
                              capture_output=True, text=True).stdout.strip() if \
                 subprocess.run(["git", "remote"], capture_output=True, text=True).stdout.strip() else None
        
        return {
            "branch": branch or "detached",
            "recent_commits": commits,
            "remote": remote,
            "has_changes": len(subprocess.run(["git", "status", "--porcelain"], 
                                           capture_output=True, text=True).stdout.strip()) > 0
        }
    
    def generate_project_profile(self, project_path):
        """Generate a comprehensive project profile."""
        structure = self.detect_structure(project_path)
        git_status = self.analyze_git_status(project_path)
        
        profile = {
            "name": os.path.basename(project_path),
            "path": project_path,
            "analyzed_at": datetime.now().isoformat(),
            "structure": structure,
            "git": git_status,
            "health": self.assess_health(structure, git_status)
        }
        
        return profile
    
    def assess_health(self, structure, git_status):
        """Assess project health."""
        issues = []
        
        if not git_status["branch"]:
            issues.append("No branch detected")
        if not git_status["remote"]:
            issues.append("No remote configured")
        if git_status["has_changes"]:
            issues.append("Uncommitted changes")
        if structure["total_files"] > 1000:
            issues.append("Large project - consider splitting")
            
        return {
            "score": max(0, 100 - len(issues) * 25),
            "issues": issues
        }
    
    def save_profile(self, profile, output_file="project.json"):
        """Save project profile."""
        with open(output_file, 'w') as f:
            json.dump(profile, f, indent=2)
        print(f"Profile saved to: {output_file}")
        return output_file

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Git Project Manager")
    parser.add_argument("--path", "-p", help="Project path", default=".")
    parser.add_argument("--profile", action="store_true", help="Generate profile")
    parser.add_argument("--output", "-o", help="Output file")
    
    args = parser.parse_args()
    
    manager = GitProjectManager(args.path)
    
    if args.profile:
        profile = manager.generate_project_profile(args.path)
        output = args.output or "project.json"
        manager.save_profile(profile, output)
        print(json.dumps(profile, indent=2))
