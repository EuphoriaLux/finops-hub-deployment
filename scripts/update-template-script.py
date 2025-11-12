#!/usr/bin/env python3
"""
Helper script to update the uploadSettings PowerShell script in template.json
This properly escapes the script for JSON insertion
"""

import json
import sys

def read_powershell_script(filepath):
    """Read the PowerShell script from file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def escape_for_json(text):
    """Escape text for JSON string format"""
    # Use json.dumps to properly escape the string
    return json.dumps(text)[1:-1]  # Remove the surrounding quotes

def update_template(template_path, script_path, output_path):
    """Update the template with the new script"""
    print(f"Reading PowerShell script from: {script_path}")
    ps_script = read_powershell_script(script_path)

    print(f"Reading template from: {template_path}")
    with open(template_path, 'r', encoding='utf-8') as f:
        template_content = f.read()

    print("Parsing template JSON...")
    template = json.loads(template_content)

    # Update the $fxv#2 variable
    print("Updating $fxv#2 variable...")
    if 'variables' in template and '$fxv#2' in template['variables']:
        template['variables']['$fxv#2'] = ps_script
        print("[SUCCESS] Successfully updated $fxv#2")
    else:
        print("[ERROR] Could not find $fxv#2 in template variables")
        return False

    print(f"Writing updated template to: {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(template, f, indent=2, ensure_ascii=False)

    print("[SUCCESS] Template updated successfully!")
    return True

if __name__ == "__main__":
    script_dir = sys.path[0] if sys.path[0] else "."
    template_path = f"{script_dir}/../template.json"
    script_path = f"{script_dir}/uploadSettings-enhanced.ps1"
    output_path = f"{script_dir}/../template.json"

    success = update_template(template_path, script_path, output_path)
    sys.exit(0 if success else 1)
