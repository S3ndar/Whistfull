
import re
import os

def extract_keys_from_map(content, start_marker, end_marker):
    start_index = content.find(start_marker)
    if start_index == -1: return set()
    end_index = content.find(end_marker, start_index)
    if end_index == -1: return set()
    map_text = content[start_index:end_index]
    return set(re.findall(r"'([^']+)':", map_text))

def extract_keys_from_code(directory):
    keys = set()
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                    content = f.read()
                    # Capture loc.translate('key') or loc.translate("key")
                    keys.update(re.findall(r"loc\.translate\(['\"]([^'\"]+)['\"]\)", content))
    return keys

loc_file = r'c:\Users\sande\Documents\Projects\Whistfull\lib\providers\localization_provider.dart'
with open(loc_file, 'r', encoding='utf-8') as f:
    content = f.read()

en_keys = extract_keys_from_map(content, '_english = {', '};')
nl_keys = extract_keys_from_map(content, '_dutch = {', '};')
code_keys = extract_keys_from_code(r'c:\Users\sande\Documents\Projects\Whistfull\lib')

print(f"Keys in Code: {len(code_keys)}")
print(f"Keys in EN Map: {len(en_keys)}")
print(f"Keys in NL Map: {len(nl_keys)}")

missing_in_en = code_keys - en_keys
missing_in_nl = code_keys - nl_keys

print(f"\nMissing in EN Map: {sorted(list(missing_in_en))}")
print(f"Missing in NL Map: {sorted(list(missing_in_nl))}")
print(f"\nIn EN but not in NL: {sorted(list(en_keys - nl_keys))}")
