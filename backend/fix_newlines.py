with open("app/services/ai/rag_engine.py", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'source_line = f"' in line and '📖' in line:
        new_lines.append('        source_line = f"\\n\\n📖 {source}" if source else ""\n')
    elif 'return f"{intro}' in line and '{retrieved_text}' in line:
        new_lines.append('        return f"{intro}\\n\\n{retrieved_text}{source_line}"\n')
    elif line.strip() == '' and len(new_lines) > 0 and 'source_line = f"' in new_lines[-1]:
        pass # Skip empty lines caused by \n\n bug
    elif '📖 {source}" if source else ""' in line:
        pass
    elif '{retrieved_text}{source_line}"' in line:
        pass
    else:
        new_lines.append(line)

with open("app/services/ai/rag_engine.py", "w", encoding="utf-8") as f:
    f.writelines(new_lines)
