@echo off
python -m nuitka --onefile --standalone --remove-output --assume-yes-for-downloads --msvc=latest --include-data-dir=files=evilfish/files main.py
