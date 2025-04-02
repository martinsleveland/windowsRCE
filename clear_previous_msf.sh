#!/bin/bash

echo "[+] Killing all Metasploit sessions..."
msfconsole -q -x "sessions -K; exit"

echo "[+] Restarting Metasploit services..."
sudo systemctl restart postgresql
sudo systemctl restart metasploit

echo "[+] Removing old payloads..."
rm -rf /root/.msf4/logs/
rm -f shell.exe

echo "[+] Cleanup complete!"
