# Zabbix Agent Installation Script
# Improved version with better error handling, logging and organization

# Configuration parameters
$config = @{
    InstallFolder    = "C:\Program Files\Zabbix Agent"
    MsiFile          = "zabbix_agent2_plugins-7.0.10-windows-amd64.msi"
    LogFile          = "C:\Program Files\Zabbix Agent\zabbix_agentd.log"
    AllowKey         = ""
    Server           = "192.168.6.76"
    ServerActive     = "::1"
    Hostname         = "myHost"
}

# Create a function for logging
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Output to console
    switch ($Level) {
        "INFO"  { Write-Host $logMessage -ForegroundColor Green }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
    }
    
    # Ensure log directory exists
    $logDir = Split-Path -Path $config.ScriptLogFile -Parent
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Write to log file
    Add-Content -Path $config.ScriptLogFile -Value $logMessage
}

# Function to uninstall existing Zabbix Agent
function Uninstall-ZabbixAgent {
    Write-Log "Checking for existing Zabbix installations..."
    
    # Define potential Zabbix installation paths
    $zabbixPaths = @{
        Path64 = "C:\Program Files\zabbix\bin\win64"
        Path86 = "C:\Program Files (x86)\zabbix\bin\win64"
        Root64 = "C:\Program Files\zabbix"
        Root86 = "C:\Program Files (x86)\zabbix"
    }
    
    # Determine which path exists for uninstallation
    $zabbixPath = $null
    $zabbixRoot = $null
    
    if (Test-Path $zabbixPaths.Path64) {
        $zabbixPath = $zabbixPaths.Path64
        $zabbixRoot = $zabbixPaths.Root64
        Write-Log "Found 64-bit Zabbix installation at $zabbixPath"
    }
    elseif (Test-Path $zabbixPaths.Path86) {
        $zabbixPath = $zabbixPaths.Path86
        $zabbixRoot = $zabbixPaths.Root86
        Write-Log "Found 32-bit Zabbix installation at $zabbixPath"
    }
    else {
        Write-Log "No existing Zabbix installation found. Skipping uninstallation."
        return
    }
    
    try {
        # Uninstall existing Zabbix Agent
        Write-Log "Uninstalling existing Zabbix Agent..."
        $currentLocation = Get-Location
        Set-Location -Path $zabbixPath
        
        $process = Start-Process -FilePath "zabbix_agentd.exe" -ArgumentList "--uninstall" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Log "Warning: Uninstallation process exited with code $($process.ExitCode)" -Level "WARN"
        }
        
        # Restore original location
        Set-Location -Path $currentLocation
        
        # Remove configuration and binary files
        Write-Log "Removing configuration files..."
        $filesToRemove = @(
            "C:\zabbix_agentd.conf",
            "C:\zabbix_agentd.exe"
        )
        
        foreach ($file in $filesToRemove) {
            if (Test-Path $file) {
                Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
                if (!(Test-Path $file)) {
                    Write-Log "Successfully removed $file"
                }
                else {
                    Write-Log "Failed to remove $file" -Level "WARN"
                }
            }
        }
        
        # Remove Zabbix installation folder
        Write-Log "Removing Zabbix installation folder..."
        if (Test-Path $zabbixRoot) {
            Remove-Item -Path $zabbixRoot -Recurse -Force -ErrorAction SilentlyContinue
            if (!(Test-Path $zabbixRoot)) {
                Write-Log "Successfully removed $zabbixRoot"
            }
            else {
                Write-Log "Failed to completely remove $zabbixRoot" -Level "WARN"
            }
        }
        
        Write-Log "Uninstallation completed"
    }
    catch {
        Write-Log "Error during uninstallation: $_" -Level "ERROR"
    }
}

# Function to install Zabbix Agent
function Install-ZabbixAgent {
    try {
        # Ensure installation folder exists
        if (!(Test-Path $config.InstallFolder)) {
            Write-Log "Creating installation folder $($config.InstallFolder)..."
            New-Item -ItemType Directory -Path $config.InstallFolder -Force | Out-Null
        }
        
        # Ensure PSK folder exists
        $pskFolder = Split-Path -Path $config.PskFile -Parent
        if (!(Test-Path $pskFolder)) {
            Write-Log "Creating PSK directory $pskFolder..."
            New-Item -ItemType Directory -Path $pskFolder -Force | Out-Null
        }
        
        # Verify MSI file exists
        if (!(Test-Path $config.MsiFile)) {
            Write-Log "MSI file not found: $($config.MsiFile)" -Level "ERROR"
            throw "MSI file not found: $($config.MsiFile)"
        }
        
        # Install new Zabbix Agent 2
        Write-Log "Installing Zabbix Agent 2..."
        
        $installArgs = @(
            "/l*v", "$(Split-Path $config.ScriptLogFile -Parent)\msi_install.log",
            "/i", "$($config.MsiFile)",
            "/qn",
            "LOGTYPE=file",
            "LOGFILE=$($config.LogFile)",
            "SERVER=$($config.Server)",
            "SERVERACTIVE=$($config.ServerActive)",
            "HOSTNAME=$($config.Hostname)",
            "ENABLEPATH=1",
            "INSTALLFOLDER=$($config.InstallFolder)",
            "SKIP=fw",
            "ALLOWDENYKEY='AllowKey=$($config.AllowKey)'"
        )
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Zabbix Agent 2 installation completed successfully."
        }
        else {
            Write-Log "Zabbix Agent 2 installation failed with exit code: $($process.ExitCode)" -Level "ERROR"
        }
        
        # Verify installation
        $serviceExists = Get-Service -Name "Zabbix Agent" -ErrorAction SilentlyContinue
        if ($serviceExists) {
            Write-Log "Zabbix Agent service installed successfully."
        }
        else {
            Write-Log "Zabbix Agent service not found after installation." -Level "WARN"
        }
    }
    catch {
        Write-Log "Error during installation: $_" -Level "ERROR"
        throw $_
    }
}

# Main execution
try {
    Write-Log "=== Starting Zabbix Agent Installation Script ==="
    
    # Uninstall existing Zabbix Agent
    Uninstall-ZabbixAgent
    
    # Install new Zabbix Agent 2
    Install-ZabbixAgent
    
    Write-Log "=== Zabbix Agent Installation Script Completed ==="
}
catch {
    Write-Log "Critical error in script execution: $_" -Level "ERROR"
    exit 1
}