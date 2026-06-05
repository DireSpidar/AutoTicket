# AutoTicket

Generates a formatted ticket file from a JSON event export. Copy your event JSON from the SIEM, run the script, and paste the output into your ticketing software.

---

## Setup

1. Clone or download this repo to your Windows machine:

   ```
   git clone --branch test-branch https://github.com/DireSpidar/AutoTicket.git
   ```

2. Open the `Templates` folder and edit `DefaultTemplate` (or create a new template file) to list the fields you want in your ticket — one field name per line.

**Example template:**
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
```

> The order of fields in the template is the order they appear in the output.  
> Fields not present in the event are collected at the bottom of the ticket for manual fill-in.  
> See `Templates\TemplateRefrence.txt` for the full list of available field names.

---

## Running the Script

1. In your SIEM, copy the raw JSON for the event you are investigating.
2. Double-click **`Run AutoTicket.bat`** (or run `AutoTicket.ps1` directly in PowerShell).
3. Choose an option from the menu:

```
AutoTicket
==========
Template: DefaultTemplate

1) Paste from clipboard and create ticket
2) Select template
3) Open template folder
4) Quit
```

**Option 1** reads JSON from your clipboard, generates the ticket using the active template, and saves it to the `ticket output` folder. You will be asked if you want the ticket copied back to your clipboard.

**Option 2** lists all templates in the `Templates` folder. Select one to make it the active template. Your selection is remembered between sessions.

**Option 3** opens the `Templates` folder in File Explorer so you can add, edit, or remove templates without leaving the script.

**Option 4** exits.

---

## Output

Tickets are saved to the `ticket output` folder as `ticket_<timestamp>.txt`.

Open the file, fill in any blank fields in the *Unpopulated Fields* section, then copy-paste the contents into your ticket.

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


Unpopulated Fields:

Time Range Investigated: 
```

---

## Adding Templates

Create a plain text file (no extension needed) in the `Templates` folder with one field name per line. The file name becomes the template name shown in the menu. `TemplateRefrence.txt` lists all available field names and is excluded from the template list automatically.
