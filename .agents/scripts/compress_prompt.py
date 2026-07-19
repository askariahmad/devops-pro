import sys
import re

# Pre-compile regex patterns for efficiency
ARTICLES_RE = re.compile(r'\b(the|a|an)\b\s*', re.IGNORECASE)
HELPERS_RE = re.compile(r'\b(is|are|was|were|have|has|had|do|does|did|been|please|really|just|very|actually)\b\s*', re.IGNORECASE)
SPACE_RE = re.compile(r'\s+')

# Common abbreviations mapping
ABBREVIATIONS = {
    r'\bkubernetes\b': 'k8s',
    r'\bterraform\b': 'tf',
    r'\bdatabase\b': 'db',
    r'\bdeployment\b': 'deploy',
    r'\bdeployments\b': 'deploys',
    r'\bservice\b': 'svc',
    r'\bservices\b': 'svcs',
    r'\bconfiguration\b': 'config',
    r'\bconfigurations\b': 'configs',
    r'\brepository\b': 'repo',
    r'\brepositories\b': 'repos',
    r'\bcontainer\b': 'ctr',
    r'\bcontainers\b': 'ctrs',
    r'\bkey\s+vault\b': 'kv',
    r'\bazure\s+container\s+registry\b': 'acr'
}

# Compile abbreviation regex patterns
ABBR_PATTERNS = [(re.compile(pattern, re.IGNORECASE), repl) for pattern, repl in ABBREVIATIONS.items()]

def compress(text):
    if not text:
        return ""
    
    # 1. Strip articles
    text = ARTICLES_RE.sub('', text)
    
    # 2. Strip auxiliary/helper verbs and fillers
    text = HELPERS_RE.sub('', text)
    
    # 3. Swap abbreviations
    for pattern, repl in ABBR_PATTERNS:
        text = pattern.sub(repl, text)
        
    # 4. Clean up spaces
    text = SPACE_RE.sub(' ', text).strip()
    return text

if __name__ == "__main__":
    raw_prompt = sys.stdin.read()
    sys.stdout.write(compress(raw_prompt))
