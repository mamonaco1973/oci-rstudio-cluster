<powershell>
$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

$Log = 'C:\ProgramData\userdata.log'
New-Item -Path $Log -ItemType File -Force | Out-Null

Start-Transcript -Path $Log -Append -Force

try {
    Write-Output "Starting PowerShell user-data at $(Get-Date -Format o)"

    Write-Output "Enabling NLA so MSTSC prompts for credentials before session starts"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
      -Name "UserAuthentication" -Value 1

    Write-Output "Setting local windows_local_admin account for RDP fallback access"
    $localPassword = "${windows_local_admin_password}" | ConvertTo-SecureString -AsPlainText -Force
    New-LocalUser -Name "windows_local_admin" -Password $localPassword -PasswordNeverExpires -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Administrators" -Member "windows_local_admin" -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member "windows_local_admin" -ErrorAction SilentlyContinue

    Write-Output "Disabling IPv6 — OCI subnets are IPv4-only"
    Get-NetAdapterBinding -ComponentID ms_tcpip6 | Disable-NetAdapterBinding

    Write-Output "Disabling Windows Update — prevents download contention during provisioning"
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Set-Service wuauserv -StartupType Disabled

    Write-Output "Installing AD management Windows features"
    Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server
    Write-Output "AD management feature install complete"

    Write-Output "Installing OCI CLI"
    $ociInstallScript = "$env:TEMP\install-oci-cli.ps1"
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1" `
        -OutFile $ociInstallScript `
        -UseBasicParsing
    powershell -NoProfile -ExecutionPolicy Bypass -File $ociInstallScript `
        --accept-all-defaults `
        --install-dir "C:\oracle\oci-cli" `
        --exec-dir "C:\oracle\oci-cli\bin"
    [Environment]::SetEnvironmentVariable(
        "PATH",
        $env:PATH + ";C:\oracle\oci-cli\bin",
        [EnvironmentVariableTarget]::Machine)
    $env:PATH += ";C:\oracle\oci-cli\bin"
    Write-Output "OCI CLI install complete"

    Write-Output "Waiting for DNS to resolve ${domain_fqdn}..."
    $dnsReady = $false
    for ($i = 1; $i -le 20; $i++) {
        try {
            Resolve-DnsName "${domain_fqdn}" -ErrorAction Stop | Out-Null
            Write-Output "DNS ready after $($i * 30)s"
            $dnsReady = $true
            break
        } catch {
            Write-Output "DNS not ready ($i/20), retrying in 30s..."
            Start-Sleep -Seconds 30
        }
    }
    if (-not $dnsReady) { throw "DNS did not resolve ${domain_fqdn} after 10 minutes" }

    Write-Output "Building domain join credential from injected values"
    $adminUsername = "${netbios}\Admin"
    $adminPassword = "${admin_password}" | ConvertTo-SecureString -AsPlainText -Force
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminUsername, $adminPassword

    Write-Output "Joining AD domain ${domain_fqdn}"
    Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force
    Write-Output "Domain join command completed"

    Write-Output "Adding ${netbios}\${lower(netbios)}-users to Remote Desktop Users"
    $domainGroup = "${netbios}\${lower(netbios)}-users"
    $maxRetries  = 10
    $retryDelay  = 30

    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $domainGroup -ErrorAction Stop
            Write-Output "SUCCESS: Added $domainGroup to Remote Desktop Users"
            break
        } catch {
            Write-Output "WARN: Attempt $i failed - waiting $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
    }

    # OCI DHCP pushes the VCN base domain as the search suffix, mangling AD FQDNs.
    # Registry SearchList overrides DHCP and survives the domain join reboot.
    Write-Output "Setting DNS suffix search list to ${domain_fqdn}"
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
        -Name 'SearchList' -Value "${domain_fqdn}"
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    Set-DnsClient -InterfaceIndex $adapter.InterfaceIndex `
        -ConnectionSpecificSuffix "${domain_fqdn}"

    # Map Z: to the Linux Samba gateway's [shared] share at every logon.
    # Placed in the All Users startup folder so domain users get the mapping
    # automatically after the domain join reboot.
    Write-Output "Creating persistent Z: drive mapping to \\${samba_server}\nfs"
    $startup   = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    $batchFile = Join-Path $startup "map_drives.bat"
    $command   = "net use Z: \\${samba_server}\nfs /persistent:yes"
    Set-Content -Path $batchFile -Value $command -Encoding ASCII
    Write-Output "Drive mapping script created"

    Write-Output "Rebooting to finalize domain join and apply group policy"
    shutdown /r /t 5 /c "Initial OCI reboot to join domain" /f /d p:4:1
}
finally {
    Write-Output "User-data finishing at $(Get-Date -Format o)"
    Stop-Transcript | Out-Null
}
</powershell>
