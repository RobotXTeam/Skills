import os
import sys
import shutil
import hashlib
import time
from datetime import datetime
import subprocess

REPO_DIR = "/home/steven/agent/Skills"
AGENTS = {
    "codex": "/home/steven/.codex/skills",
    "gemini": "/home/steven/.gemini/skills",
    "claude": "/home/steven/.claude/skills"
}
IGNORE_DIRS = {".system", "skills-backups", ".git", "__pycache__", ".sync-backups"}

def get_files(d):
    files = []
    for root, dirs, filenames in os.walk(d):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for f in filenames:
            files.append(os.path.relpath(os.path.join(root, f), d))
    return sorted(files)

def hash_dir(d):
    files = get_files(d)
    h = hashlib.sha256()
    for f in files:
        h.update(f.encode('utf-8'))
        p = os.path.join(d, f)
        if os.path.isfile(p):
            with open(p, 'rb') as f_obj:
                h.update(f_obj.read())
    return h.hexdigest()

def calc_metrics(d):
    files = get_files(d)
    non_ws = 0
    bytes_count = 0
    mtime_max = 0
    
    for f in files:
        p = os.path.join(d, f)
        if os.path.isfile(p):
            try:
                st = os.stat(p)
                mtime_max = max(mtime_max, st.st_mtime)
                bytes_count += st.st_size
                with open(p, 'r', encoding='utf-8') as f_obj:
                    content = f_obj.read()
                    non_ws += len(content) - content.count(' ') - content.count('\n') - content.count('\r') - content.count('\t')
            except UnicodeDecodeError:
                pass # skip non-ws for binary
    return (non_ws, bytes_count, len(files), mtime_max)

# Discover local skills
local_skills = {} # (skill_lower, agent) -> (local_path, orig_skill_name)
for agent, base_dir in AGENTS.items():
    if not os.path.exists(base_dir): continue
    for d in os.listdir(base_dir):
        p = os.path.join(base_dir, d)
        if os.path.isdir(p) and d not in IGNORE_DIRS:
            if os.path.isfile(os.path.join(p, "SKILL.md")):
                local_skills[(d.lower(), agent)] = (p, d)

# Discover repo skills
repo_skills = {} # (skill_lower, agent) -> (repo_path, orig_skill_name)
repo_casing = {}
for d in os.listdir(REPO_DIR):
    p = os.path.join(REPO_DIR, d)
    if os.path.isdir(p) and d not in IGNORE_DIRS:
        repo_casing[d.lower()] = d
        for agent in AGENTS.keys():
            ap = os.path.join(p, agent)
            if os.path.isdir(ap) and os.path.isfile(os.path.join(ap, "SKILL.md")):
                repo_skills[(d.lower(), agent)] = (ap, d)

all_keys = set(local_skills.keys()) | set(repo_skills.keys())

backup_time = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_base = os.path.join(REPO_DIR, ".sync-backups", backup_time)

copied_local_to_repo = []
copied_repo_to_local = []
skipped = []
repo_changed = False

def do_backup(src_path, dest_is_repo):
    if not os.path.exists(src_path): return
    # If dest_is_repo is true, we are backing up the repo. Else backing up local.
    # Keep it simple, just backup to backup_base
    rel = src_path.replace("/home/steven/", "").replace("/", "_")
    bp = os.path.join(backup_base, rel)
    os.makedirs(os.path.dirname(bp), exist_ok=True)
    shutil.copytree(src_path, bp)

def do_copy(src, dst):
    if os.path.exists(dst):
        shutil.rmtree(dst)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copytree(src, dst)

for key in sorted(all_keys):
    skill_lower, agent = key
    local_p, orig_local = local_skills.get(key, (None, None))
    repo_p, orig_repo = repo_skills.get(key, (None, None))
    
    # Determine repo path if not exists
    if not repo_p:
        casing = repo_casing.get(skill_lower, orig_local)
        repo_p = os.path.join(REPO_DIR, casing, agent)
    
    # Determine local path if not exists
    if not local_p:
        casing = orig_repo
        local_p = os.path.join(AGENTS[agent], casing)

    if local_p and repo_p and os.path.exists(local_p) and os.path.exists(repo_p):
        h_loc = hash_dir(local_p)
        h_rep = hash_dir(repo_p)
        if h_loc == h_rep:
            skipped.append(f"{agent}/{orig_local or orig_repo}")
            continue
        
        m_loc = calc_metrics(local_p)
        m_rep = calc_metrics(repo_p)
        
        if m_loc > m_rep:
            # local wins
            do_backup(repo_p, True)
            do_copy(local_p, repo_p)
            copied_local_to_repo.append(f"{agent}/{orig_local or orig_repo}")
            repo_changed = True
        else:
            # repo wins
            do_backup(local_p, False)
            do_copy(repo_p, local_p)
            copied_repo_to_local.append(f"{agent}/{orig_local or orig_repo}")
    elif local_p and os.path.exists(local_p):
        do_copy(local_p, repo_p)
        copied_local_to_repo.append(f"{agent}/{orig_local or orig_repo}")
        repo_changed = True
    elif repo_p and os.path.exists(repo_p):
        do_copy(repo_p, local_p)
        copied_repo_to_local.append(f"{agent}/{orig_repo}")

print("=== Sync Report ===")
print("Skills copied from local tools to repo:")
for x in copied_local_to_repo: print(f"  - {x}")
if not copied_local_to_repo: print("  (none)")

print("\nSkills copied from repo to local tools:")
for x in copied_repo_to_local: print(f"  - {x}")
if not copied_repo_to_local: print("  (none)")

print("\nSkipped identical skills:")
for x in skipped: print(f"  - {x}")
if not skipped: print("  (none)")

if os.path.exists(backup_base):
    print(f"\nBackup directory: {backup_base}")

if repo_changed:
    print("\nCommitting and pushing repo changes...")
    subprocess.run(["git", "add", "."], cwd=REPO_DIR)
    subprocess.run(["git", "commit", "-m", "Sync local CLI skills"], cwd=REPO_DIR)
    res = subprocess.run(["git", "push"], cwd=REPO_DIR)
    print("Push succeeded!" if res.returncode == 0 else "Push failed!")
else:
    print("\nNo repo changes to push.")

