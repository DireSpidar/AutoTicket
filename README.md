# AutoTicket

Generates a formatted ticket file from a JSON event export. Fill out the template with the fields you want, run the script against the event, and copy-paste the output into your ticketing software.

---

## Setup

1. Clone or download this repo to your Windows machine.
2. Open `template.txt` and list the fields you want in your ticket — one per line, exactly as they appear in the event table. Lines starting with `#` are ignored.

**Example `template.txt`:**
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

---

## Running the Script

1. Export the event JSON from the event tracking software and save it as a `.json` file.
2. Open PowerShell and navigate to the AutoTicket folder.
3. Run:

```powershell
.\AutoTicket.ps1 -EventFile "path\to\event.json"
```

**Example:**
```powershell
.\AutoTicket.ps1 -EventFile "C:\Users\you\Downloads\event.json"
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

@timestamp: 2025-01-15T14:32:00.000Z

source.ip: 192.168.1.105

source.port: 52341

destination.ip: 203.0.113.42

destination.port: 443

network.direction: outbound

Time Range Investigated: 
```
