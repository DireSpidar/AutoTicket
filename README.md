# AutoTicket

Generates a formatted ticket file from a JSON event export. Fill out the template with the fields you want, run the script, and copy-paste the output into your ticketing software.

---

## Setup

1. Clone or download this repo to your Windows machine:
    git clone https://github.com/DireSpidar/AutoTicket.git
2. Open `UserTemplate.txt` and list the fields you want in your ticket — one per line, exactly as they appear in the event table. Lines starting with `#` are ignored.

**Example `UserTemplate.txt`:**
```
agent.name
rule.name
rule.category
@timestamp
source.ip
source.port
destination.ip
destination.port
network.direction
Time Range Investigated
```

> The order of fields in the template is the order they appear in the output.  
> Fields with no value in the event (or manual fields like `Time Range Investigated`) are left blank for you to fill in.  
> See the bottom section of `UserTemplate.txt` for the full list of available field names.

---

## Running the Script

1. Open the event in your tracking software and copy the raw JSON data.
2. Open `PasteEventHere.json`, select all, paste the copied JSON, and save the file.
3. Open PowerShell and navigate to the AutoTicket folder.
4. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\AutoTicket.ps1
```

The script reads from `PasteEventHere.json` automatically. If you prefer to point it at a different file, you can pass the path directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\AutoTicket.ps1 -EventFile "path\to\event.json"
```

> **First time only:** If PowerShell blocks the script, run this first:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

---

## Output

The ticket file is saved to the `output\` folder inside the AutoTicket directory, named `ticket_<timestamp>.txt`.

Open it, fill in any blank fields, then copy-paste the contents into your ticket.

**Example output:**
```
agent.name: SensorHost01

rule.name: Suspicious Outbound Connection

rule.category: Trojan Activity

@timestamp: January 15, 2025 @ 07:32:00.000

source.ip: 192.168.1.105

source.port: 52341

destination.ip: 203.0.113.42

destination.port: 443

network.direction: outbound

Time Range Investigated: 
```
