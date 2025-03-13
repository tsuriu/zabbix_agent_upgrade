# Zabbix Agent Install & Uninstall Scripts

This repository contains scripts for automating the installation and uninstallation of the Zabbix Agent on Windows (PowerShell) and Linux (Shell Script) systems.

## Files
- **zabbixAgentJobs.ps1** - PowerShell script for Windows to uninstall an existing Zabbix Agent and install Zabbix Agent 2.
- **zabbixAgentJobs.sh** - Shell script for CentOS/RedHat to remove an old Zabbix Agent and install Zabbix Agent 2.

## Usage

### Windows (PowerShell)
#### Prerequisites
- Windows OS
- Administrator privileges
- Zabbix Agent MSI package available

#### Steps
1. Open PowerShell as Administrator.
2. Navigate to the script location.
3. Run the script:
   ```powershell
   ./zabbixAgentJobs.ps1
   ```

### Linux (Shell Script)
#### Prerequisites
- CentOS / RedHat-based system
- Root privileges
- Zabbix Agent RPM package available

#### Steps
1. Give execution permission:
   ```bash
   chmod +x zabbixAgentJobs.sh
   ```
2. Run the script:
   ```bash
   sudo ./zabbixAgentJobs.sh
   ```

## Features
- Detects existing Zabbix installation and removes it.
- Installs Zabbix Agent 2 with predefined configuration settings.
- Automatically starts and enables the Zabbix Agent service after installation.

## Notes
- Ensure the necessary Zabbix installation packages (MSI/RPM) are available in the same directory before running the scripts.
- Modify configuration parameters as needed in the script before execution.

## License
MIT License