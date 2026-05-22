#!/usr/bin/env python3
"""
Agent Brain Backup
Backs up agent memories, skills, and configurations to brains repository.
"""

import subprocess
import os
import json
import shutil
from datetime import datetime
from pathlib import Path

class AgentBrainBackup:
    def __init__(self):
        selfbrains_repo = "git@github.com:aatosai/brains.git"
        self.backup_dir = "/tmp/brains-backup"
        self.agents_dir = "agents"
        
    def backup_agent(self, agent_name, agent_path):
        """Backup a single agent."""
        print(f"\n🧠 Backing up agent: {agent_name}")
        print("=" * 50)
        
        agent_backup_path = os.path.join(self.backup_dir, self.agents_dir, agent_name)
        os.makedirs(agent_backup_path, exist_ok=True)
        
        # Copy agent files
        items_copied = 0
        for item in os.listdir(agent_path):
            src = os.path.join(agent_path, item)
            dst = os.path.join(agent_backup_path, item)
            
            if os.path.isdir(src):
                if item not in ['.git', 'node_modules', '__pycache__']:
                    shutil.copytree(src, dst, dirs_exist_ok=True)
                    items_copied += 1
            else:
                shutil.copy2(src, dst)
                items_copied += 1
                
        print(f"   ✅ Copied {items_copied} items")
        
        # Create metadata
        metadata = {
            "agent_name": agent_name,
            "source_path": agent_path,
            "backed_up_at": datetime.now().isoformat(),
            "items": items_copied
        }
        
        with open(os.path.join(agent_backup_path, ".brain-metadata.json"), 'w') as f:
            json.dump(metadata, f, indent=2)
            
        return agent_backup_path
    
    def backup_all_agents(self, agents_source="/root/hermes-workspace"):
        """Backup all agents from source directory."""
        print("\n🧠 Agent Brain Backup")
        print("=" * 50)
        print(f"Source: {agents_source}")
        print(f"Backup dir: {self.backup_dir}")
        
        # Clean and create backup dir
        if os.path.exists(self.backup_dir):
            shutil.rmtree(self.backup_dir)
        os.makedirs(self.backup_dir, exist_ok=True)
        
        # Find all agents
        agents_found = []
        for item in os.listdir(agents_source):
            path = os.path.join(agents_source, item)
            if os.path.isdir(path):
                # Check if it looks like an agent (has SKILL.md or similar)
                if os.path.exists(os.path.join(path, "SKILL.md")) or \
                   os.path.exists(os.path.join(path, "agent-config.json")):
                    agents_found.append((item, path))
        
        print(f"\nFound {len(agents_found)} agents:")
        for name, path in agents_found:
            print(f"   - {name}")
            
        # Backup each agent
        backed_up = []
        for name, path in agents_found:
            self.backup_agent(name, path)
            backed_up.append(name)
            
        # Create manifest
        manifest = {
            "backup_at": datetime.now().isoformat(),
            "source": agents_source,
            "agents_backed_up": backed_up,
            "total_agents": len(backed_up)
        }
        
        manifest_path = os.path.join(self.backup_dir, "manifest.json")
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
            
        print(f"\n✅ Backed up {len(backed_up)} agents")
        print(f"📁 Backup location: {self.backup_dir}")
        print(f"📄 Manifest: {manifest_path}")
        
        return self.backup_dir
    
    def push_to_brains(self, commit_message=None):
        """Push backup to brains repository."""
        os.chdir(self.backup_dir)
        
        # Initialize git if needed
        if not os.path.exists(os.path.join(self.backup_dir, ".git")):
            subprocess.run(["git", "init"], capture_output=True)
            subprocess.run(["git", "remote", "add", "origin", self.brains_repo], capture_output=True)
            
        # Add all files
        subprocess.run(["git", "add", "-A"], capture_output=True)
        
        # Commit
        msg = commit_message or f"Agent brain backup - {datetime.now().isoformat()}"
        result = subprocess.run(["git", "commit", "-m", msg], capture_output=True, text=True)
        
        if "nothing to commit" in result.stdout:
            print("No changes to commit")
            return
            
        # Push
        print(f"\n🚀 Pushing to brains repository...")
        result = subprocess.run(["git", "push", "origin", "main"], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Successfully pushed to brains!")
        else:
            print(f"❌ Push failed: {result.stderr}")
            
        return result.returncode

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Agent Brain Backup")
    parser.add_argument("--source", "-s", help="Source directory", default="/root/hermes-workspace")
    parser.add_argument("--push", action="store_true", help="Push to brains repo")
    parser.add_argument("--message", "-m", help="Commit message")
    
    args = parser.parse_args()
    
    backup = AgentBrainBackup()
    backup.backup_all_agents(args.source)
    
    if args.push:
        backup.push_to_brains(args.message)
