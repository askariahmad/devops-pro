import sys
import re

def compress(text):
    if not text:
        return ""
    
    # 1. Remove articles (the, a, an)
    text = re.sub(r'\b(the|a|an)\b\s*', '', text, flags=re.IGNORECASE)
    
    # 2. Remove auxiliary verbs and polite fillers
    fillers = r'\b(is|are|was|were|have|has|had|do|does|did|been|please|really|just|very|actually)\b\s*'
    text = re.sub(fillers, '', text, flags=re.IGNORECASE)
    
    # 3. Clean up whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text

if __name__ == "__main__":
    # Read full prompt from stdin
    raw_prompt = sys.stdin.read()
    compressed_prompt = compress(raw_prompt)
    # Output to stdout for Antigravity to capture
    sys.stdout.write(compressed_prompt)
