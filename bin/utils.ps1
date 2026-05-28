function Get-LanzouList {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Uri,
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $Pass
    )
    $sharekey = $Uri -split '/' | Select-Object -Last 1
    $webcontent = Invoke-RestMethod -Uri "https://www.lanzoui.com/$sharekey" -UseBasicParsing
    $ajaxm = [regex]::Match($webcontent, '\/filemoreajax\.php\?file=\d+').Value
    $body = @()
    $body += "lx=2"
    $body += "fid=$([regex]::Match($webcontent, "'fid':(\w+)").Groups[1].Value)"
    $body += "uid=$([regex]::Match($webcontent, "'uid':(\w+)").Groups[1].Value)"
    $body += "pg=1"
    $body += "rep=0"
    $body += "t=$([regex]::Match($webcontent, "var $($([regex]::Match($webcontent, "'t':(\w+)").Groups[1].Value)) = '(\w+)'").Groups[1].Value)"
    $body += "k=$([regex]::Match($webcontent, "var $($([regex]::Match($webcontent, "'k':(\w+)").Groups[1].Value)) = '(\w+)'").Groups[1].Value)"
    $body += "up=1"
    if ($Pass) { $body += "pwd=$Pass" }
    $body = $body -join "&"
    $list = Invoke-RestMethod -Uri "https://www.lanzoui.com$ajaxm" -Method Post -Body $body
    return $list.text
}

# function Get-XRSoft {
#     if (!$Global:XRSoft) {
#         $wc = New-Object System.Net.WebClient
#         $wc.Encoding = [System.Text.Encoding]::GetEncoding("GBK")
#         $content = $wc.DownloadString("https://c.xrgzs.top/SoftN.ini")
#         $Global:XRSoft = $content | ConvertFrom-Ini
#     }
#     return $Global:XRSoft
# }

function ConvertFrom-HtmlEncodedText {
    <#
    .SYNOPSIS
      Converts a string that has been HTML-encoded for HTTP transmission into a decoded string.
    .PARAMETER InputObject
      The string to be decoded
    #>
    [OutputType([string])]
    param (
        [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The string to be decoded')]
        [string]
        $InputObject
    )

    process {
        [System.Net.WebUtility]::HtmlDecode($InputObject)
    }
}


function ConvertFrom-Ini {
    <#
    .SYNOPSIS
      Convert INI string into ordered hashtable
    .PARAMETER InputObject
      The INI string to be converted
    .PARAMETER CommentChars
      The characters that describe a comment
      Lines starting with the characters provided will be rendered as comments
      Default: ";"
    .PARAMETER IgnoreComments
      Remove lines determined to be comments from the resulting dictionary
    .NOTES
      This code is modified from https://github
      
      .com/lipkau/PsIni under the MIT license

      The MIT License (MIT)

      Copyright (c) 2019 Oliver Lipkau

      Permission is hereby granted, free of charge, to any person obtaining a copy
      of this software and associated documentation files (the "Software"), to deal
      in the Software without restriction, including without limitation the rights
      to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
      copies of the Software, and to permit persons to whom the Software is
      furnished to do so, subject to the following conditions:

      The above copyright notice and this permission notice shall be included in all
      copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
      IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
      FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
      AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
      LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
      OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
      SOFTWARE.
    .LINK
      https://github.com/lipkau/PsIni
    #>
    # [OutputType([ordered])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The INI string to be converted')]
        [AllowEmptyString()]
        [string]
        $Content,

        [Parameter(
            HelpMessage = 'The characters that describe a comment'
        )]
        [char[]]
        $CommentChars = @(';'),

        [Parameter(
            HelpMessage = 'Remove lines determined to be comments from the resulting dictionary'
        )]
        [switch]
        $IgnoreComments
    )

    begin {
        $SectionRegex = '^\s*\[(.+)\]\s*$'
        $KeyRegex = "^\s*(.+?)\s*=\s*(['`"]?)(.*)\2\s*$"
        $CommentRegex = "^\s*[$($CommentChars -join '')](.*)$"

        # Name of the section, in case the INI string had none
        $RootSection = '_'

        $Object = [ordered]@{}
        $CommentCount = 0
    }

    process {
        $StringReader = [System.IO.StringReader]::new($Content)

        for ($Text = $StringReader.ReadLine(); $null -ne $Text; $Text = $StringReader.ReadLine()) {
            switch -Regex ($Text) {
                $SectionRegex {
                    $Section = $Matches[1]
                    $Object[$Section] = [ordered]@{}
                    $CommentCount = 0
                    continue
                }
                $CommentRegex {
                    if (-not $IgnoreComments) {
                        if (-not $Section) {
                            $Section = $RootSection
                            $Object[$Section] = [ordered]@{}
                        }
                        $Key = '#Comment' + ($CommentCount++)
                        $Value = $Matches[1]
                        $Object[$Section][$Key] = $Value
                    }
                    continue
                }
                $KeyRegex {
                    if (-not $Section) {
                        $Section = $RootSection
                        $Object[$Section] = [ordered]@{}
                    }
                    $Key = $Matches[1]
                    $Value = $Matches[3].Replace('\r', "`r").Replace('\n', "`n")
                    if ($Object[$Section][$Key]) {
                        if ($Object[$Section][$Key] -is [array]) {
                            $Object[$Section][$Key] += $Value
                        }
                        else {
                            $Object[$Section][$Key] = @($Object[$Section][$Key], $Value)
                        }
                    }
                    else {
                        $Object[$Section][$Key] = $Value
                    }
                    continue
                }
            }
        }

        $StringReader.Dispose()
    }

    end {
        return $Object
    }
}

function Get-RedirectedUrl1st {
    <#
    .SYNOPSIS
      Get the first redirected URL from the given URL
    .PARAMETER Uri
      The Uniform Resource Identifier (URI) that will be redirected
    .PARAMETER UserAgent
      The user agent string for the web request
    #>
    [OutputType([string])]
    param (
        [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The URI that will be redirected')]
        [string]
        $Uri,

        [Parameter(HelpMessage = 'The user agent string for the web request')]
        [string]
        $UserAgent,

        [Parameter(HelpMessage = 'The user agent string for the web request')]
        [System.Collections.IDictionary]
        $Headers
    )

    process {
        $Request = [System.Net.WebRequest]::Create($Uri)
        if ($UserAgent) {
            $Request.UserAgent = $UserAgent
        }
        if ($Headers) {
            $Headers.GetEnumerator() | ForEach-Object -Process { $Request.Headers.Set($_.Key, $_.Value) }
        }
        $Request.AllowAutoRedirect = $false
        $Response = $Request.GetResponse()
        Write-Output -InputObject $Response.GetResponseHeader('Location')
        $Response.Close()
    }
}
function New-PersistDirectory {
    param (
        [parameter(Mandatory = $true, Position = 0)]
        [string]
        $dataPath,

        [parameter(Mandatory = $true, Position = 1)]
        [string]
        $persistPath,

        [switch] 
        $Migrate
    )
    # Create persist dir
    New-Item $persistPath -Type Directory -Force -ErrorAction SilentlyContinue | Out-Null
    if (Test-Path $dataPath) {
        $dataPathItem = Get-Item -Path $dataPath
        if ($dataPathItem.LinkType -eq 'Junction') {
            # Delete old Junction
            # Remove-Item regard junction as actual directory, do not use it.
            try { $dataPathItem.Delete() } catch {}
        }
        else {
            if ($Migrate) {
                # Migrate data
                Get-ChildItem $dataPath | ForEach-Object { Move-Item $_.FullName $persistPath -Force -ErrorAction SilentlyContinue | Out-Null }
            }
            Remove-Item $dataPath -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        }
    }
    # Create new Junction
    New-Item -ItemType Junction -Path $dataPath -Target $persistPath | Out-Null
}

function Remove-Junction {
    param (
        [parameter(Mandatory = $true, Position = 0)]
        [string]
        $dataPath
    )
    # Delete Junction only
    $dataPathItem = Get-Item -Path $dataPath
    try { $dataPathItem.Delete() } catch {}
}

function Set-RegValue {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Path,

        [Parameter(Mandatory, Position = 1)]
        [string]
        $Name,

        [Parameter(Mandatory, Position = 2)]
        [object]
        $Value,

        [Parameter(Position = 3)]
        [ValidateSet("REG_SZ", "REG_EXPAND_SZ", "REG_MULTI_SZ", "REG_DWORD", "REG_QWORD", "REG_BINARY")]
        [string]
        $Type,

        [Parameter()]
        [switch]
        $Wow64
    )
    try {
        if ((Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop) -ne $Value) { throw }
    }
    catch {
        $Path = $Path.Replace(':', '')
        $ArgumentList = @("add `"$Path`" /f /v `"$Name`" /d `"$Value`"")
        if ($Type) { $ArgumentList += "/t $Type" }
        if ($Wow64) { $ArgumentList += "/reg:32" }
        Start-Process -FilePath "reg.exe" -ArgumentList $ArgumentList -Wait -Verb "RunAs" -WindowStyle Hidden
    }
}

function Enable-DevelopmentMode {
    try {
        Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowAllTrustedApps" -Value 1 -Type REG_DWORD
        Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type REG_DWORD
    }
    catch {
        Write-Error "This App requires enable developmoent mode to install. Failed to enable development mode. Please reinstall this App."
        exit 1
    }
}

function New-AppLink {
    param(
        [string] $App,
        [string] $Target,
        [string] $Name = $App
    )
    New-Item -ItemType Directory -Path $Target -Force -ErrorAction SilentlyContinue | Out-Null
    $AppItem = scoop which $App | Get-Item
    try {
        New-Item -ItemType SymbolicLink -Target $AppItem.FullName -Path "$Target\$Name.exe" -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Copy-Item -Path "$scoopdir\shims\$App.exe" -Destination "$Target\$Name.exe" -Force | Out-Null
        Copy-Item -Path "$scoopdir\shims\$App.shim" -Destination "$Target\$Name.shim" -Force | Out-Null
    }
}

function Convert-PngToIco {
    <#
    .LINK
        https://www.xrgzs.top/posts/powershell-png-to-ico
    #>
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$PngPath,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$IcoPath
    )
    $png = [System.IO.File]::ReadAllBytes($pngPath)
    $ico = [System.IO.MemoryStream]::new()
    $bin = [System.IO.BinaryWriter]::new($ico)
    $bin.Write([uint16]0) # 保留
    $bin.Write([uint16]1) # 图像类型，ico 为 1
    $bin.Write([uint16]1) # 图像数量，1 张
    $bin.Write([sbyte]0) # 宽度
    $bin.Write([sbyte]0) # 高度
    $bin.Write([sbyte]0) # 颜色
    $bin.Write([sbyte]0) # 保留
    $bin.Write([uint16]1) # 颜色平面
    $bin.Write([uint16]32) # 每像素位数（32bpp）
    $bin.Write([uint32]$png.Length) # 图像文件大小
    $bin.Write([uint32]22) # 图像数据偏移量
    $bin.Write($png)
    [System.IO.File]::WriteAllBytes($icoPath, $ico.ToArray())
    $bin.Dispose()
    $ico.Dispose()
}


# Auto select language
function Auto_Lang([scriptblock]$CN = {}, [scriptblock]$EN = {}) {
    if ($lang -eq 'zh-CN') { & $CN }else { & $EN }
}

# Confirm the operation
function Confirm-Action {
    param(
        [string]$Message = "`nMake sure all processes of the '$app' are stopped. Do you want to continue?"
    )
    Write-Host "$Message (y/n) " -f DarkYellow -NoNewline
    $confirmation = Read-Host
    while ($true) {
        if ($confirmation -eq 'y') {
            Write-Host "Continuing to uninstall..." -NoNewline
            break
        }
        else {
            Write-Host "Action canceled." -f DarkRed
            exit
        }
    }
}

# Ensure current operation is running with administrator privileges.
function Require-Admin {
    param(
        [string]$Prompt = "[ERROR] Requires admin rights to run. Use admin rights? (y/n)"
    )

    $isAdmin = ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [System.Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($isAdmin) {
        return
    }

    Write-Host "`n$Prompt " -ForegroundColor Red -NoNewline
    $confirmation = Read-Host

    if ([string]::IsNullOrWhiteSpace($confirmation) -or $confirmation -match '^(?i:y|yes)$') {
        $elevatedCommand = @"
Add-Type -AssemblyName System.Windows.Forms
Start-Sleep -Milliseconds 350
[System.Windows.Forms.SendKeys]::SendWait('{UP}{ENTER}')
"@

        $terminal = Get-Command "wt.exe" -ErrorAction SilentlyContinue
        if ($terminal) {
            Start-Process -FilePath $terminal.Source -Verb RunAs -ArgumentList @(
                "powershell.exe",
                "-NoExit",
                "-ExecutionPolicy", "Bypass",
                "-Command", $elevatedCommand
            ) | Out-Null
        }
        else {
            Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @(
                "-NoExit",
                "-ExecutionPolicy", "Bypass",
                "-Command", $elevatedCommand
            ) | Out-Null
        }

        abort "Current operation terminated. Continue in elevated terminal."
    }

    abort $Prompt
}

# Remove application data (local directories and registry entries)
<#
.SYNOPSIS
    Remove application data including local directories and registry entries.

.DESCRIPTION
    This function removes application data by deleting specified local directories and registry entries.
    It continues execution even if paths don't exist or deletion fails.

.PARAMETER LocalPaths
    Array of local directory paths to delete (e.g., environment variables like $env:LOCALAPPDATA)

.PARAMETER RegistryPaths
    Array of registry paths to delete (e.g., 'HKCU:\SOFTWARE\AppName')

.EXAMPLE
    Remove-AppData -LocalPaths @(
        "$env:LOCALAPPDATA\AppName",
        "$env:APPDATA\AppName"
    ) -RegistryPaths @(
        "HKCU:\SOFTWARE\AppName",
        "HKCU:\SOFTWARE\Classes\AppName*"
    )
#>
function Remove-AppData {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$LocalPaths,

        [Parameter(Mandatory = $false)]
        [string[]]$RegistryPaths,

        [Parameter(Mandatory = $false)]
        [string[]]$RegistryValues,

        [Parameter(Mandatory = $false)]
        [hashtable]$ConditionalRegistry
    )

    # Remove local directories
    if ($LocalPaths) {
        foreach ($path in $LocalPaths) {
            if ($path -and (Test-Path $path)) {
                Write-Host "`nDeleting $path ..." -f DarkGray -NoNewline
                Remove-Item $path -Force -Recurse
            }
        }
    }

    # Remove registry entries (entire keys)
    if ($RegistryPaths) {
        Write-Host "`nDeleting registry entries ..." -f DarkGray -NoNewline
        foreach ($regPath in $RegistryPaths) {
            if ($regPath) {
                # Convert PowerShell registry path to reg.exe format
                $regPath = $regPath -replace 'Registry::', ''
                $regPath = $regPath -replace ':', ''
                # Execute reg.exe delete
                reg.exe delete "$regPath" /f 2>$null | Out-Null
            }
        }
    }

    # Remove specific registry values
    if ($RegistryValues) {
        foreach ($regValue in $RegistryValues) {
            if ($regValue) {
                # Format: "path|valuename"
                $parts = $regValue -split '\|', 2
                if ($parts.Count -eq 2) {
                    $regPath = $parts[0] -replace 'Registry::', '' -replace ':', ''
                    $valueName = $parts[1]
                    reg.exe delete "$regPath" /v "$valueName" /f 2>$null | Out-Null
                }
            }
        }
    }

    # Remove conditional registry entries
    if ($ConditionalRegistry) {
        foreach ($condition in $ConditionalRegistry.Keys) {
            $shouldDelete = $false
            
            if ($condition -eq 'uninstall' -and $cmd -eq 'uninstall') {
                $shouldDelete = $true
            }
            elseif ($condition -eq 'global-uninstall' -and $global -and $cmd -eq 'uninstall') {
                $shouldDelete = $true
            }
            
            if ($shouldDelete) {
                $paths = $ConditionalRegistry[$condition]
                foreach ($regPath in $paths) {
                    if ($regPath) {
                        $regPath = $regPath -replace 'Registry::', '' -replace ':', ''
                        reg.exe delete "$regPath" /f 2>$null | Out-Null
                    }
                }
            }
        }
    }
}

# Check Scoop repository remote URL
<#
.SYNOPSIS
    Check if Scoop bucket is from specified remote URLs.

.DESCRIPTION
    This function checks if the Scoop installation's remote URL matches one of the specified URLs.
    If Scoop is from cmontage/scoop (GitHub or Gitee), the function returns $false to skip script execution.

.PARAMETER RemoteUrls
    Array of remote URLs to check against (default: cmontage's GitHub and Gitee repos)

.EXAMPLE
    if (Test-ScoopRemote) {
        Write-Host "Skipping process stop - using cmontage/scoop"
        return
    }

.RETURNS
    $true if remote is cmontage/scoop (should skip execution)
    $false otherwise (should proceed with execution)
#>
function Test-ScoopRemote {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$RemoteUrls = @(
            "https://github.com/cmontage/scoop",
            "https://gitee.com/cmontage/scoop"
        )
    )

    try {
        # Get Scoop directory from environment or default location
        $scoopRoot = $env:SCOOP
        if (-not $scoopRoot) {
            $scoopRoot = "$env:USERPROFILE\scoop"
        }

        # Check if apps/scoop directory exists and contains git config
        $scoopGitConfig = Join-Path $scoopRoot "apps\scoop\current\.git\config"
        
        if (-not (Test-Path $scoopGitConfig)) {
            # Try alternative path
            $scoopGitConfig = Join-Path $scoopRoot "apps\scoop\.git\config"
        }

        if (Test-Path $scoopGitConfig) {
            $gitConfig = Get-Content $scoopGitConfig -Raw
            
            # Extract remote URL
            $urlMatch = [regex]::Match($gitConfig, 'url\s*=\s*(.+?)(?:\s|$)')
            if ($urlMatch.Success) {
                $remoteUrl = $urlMatch.Groups[1].Value.Trim()
                
                # Check if remote URL matches any of the specified URLs
                foreach ($url in $RemoteUrls) {
                    # Normalize URLs for comparison (remove trailing .git, case-insensitive)
                    $normalizedRemote = $remoteUrl -replace '\.git$', '' -replace '/$', ''
                    $normalizedCheck = $url -replace '\.git$', '' -replace '/$', ''
                    
                    if ($normalizedRemote -eq $normalizedCheck) {
                        Write-Host "`nScoop remote is from cmontage/scoop. Skipping process termination." -ForegroundColor Yellow
                        return $true
                    }
                }
            }
        }
    }
    catch {
        Write-Host "Error checking Scoop remote: $_" -ForegroundColor Yellow
    }

    return $false
}

# Stop process with elevation retry capability
<#
.SYNOPSIS
    Stop running application processes with automatic admin elevation retry.

.DESCRIPTION
    This function attempts to stop running processes for an application.
    If the initial attempt fails, it retries with administrator privileges.

.PARAMETER ProcessNames
    Array of process names to stop (e.g., "Spark", "App")

.PARAMETER Path
    Array of file paths to search for running executables (optional)

.PARAMETER TimeoutSeconds
    Timeout in seconds to wait for process termination (default: 30)

.EXAMPLE
    Stop-ProcessWithElevation -ProcessNames @("Spark", "SparkDesktop")

.EXAMPLE
    Stop-ProcessWithElevation -ProcessNames @("Spark") -Path @("$env:LOCALAPPDATA\Spark")
#>
function Stop-App {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$ProcessNames,

        [Parameter(Mandatory = $false)]
        [string[]]$Path,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    # Check if should skip based on Scoop remote
    if (Test-ScoopRemote) {
        # Write-Host "Skipping process termination - using cmontage/scoop repository." -ForegroundColor Green
        return
    }

    # Use default paths if none provided
    if (-not $Path -and -not $ProcessNames) {
        $Path = @($dir, "$dir\app")
    }

    # Collect all processes to terminate
    $processesToKill = @()
    
    # First, add processes found by name
    if ($ProcessNames -and $ProcessNames.Count -gt 0) {
        foreach ($processName in $ProcessNames) {
            try {
                $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if ($processes) {
                    $processesToKill += $processes
                }
            }
            catch {
                # Silently continue if process not found
            }
        }
    }

    # Second, search by file path
    if ($Path -and $Path.Count -gt 0) {
        try {
            $allProcesses = Get-Process -ErrorAction SilentlyContinue
            
            foreach ($searchPath in $Path) {
                $matchedProcesses = $allProcesses | Where-Object {
                    @($_.Modules.FileName) -like "$searchPath\*"
                }
                
                foreach ($proc in $matchedProcesses) {
                    # Avoid duplicates
                    if ($processesToKill.Id -notcontains $proc.Id) {
                        $processesToKill += $proc
                    }
                }
            }
        }
        catch {
            # Silently continue on error
        }
    }

    # If no processes found, exit gracefully
    if ($processesToKill.Count -eq 0) {
        Write-Host "`nNo processes found to terminate." -ForegroundColor Green -NoNewline
        return
    }

    Write-Host "`nStopping processes..." -ForegroundColor Yellow -NoNewline

    $needsElevation = $false

    # First attempt: Kill processes without elevation
    foreach ($proc in $processesToKill) {
        try {
            Write-Host "`n Terminating: $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Gray -NoNewline
            $proc | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "`n Error stopping $($proc.ProcessName): $_" -ForegroundColor Yellow -NoNewline
            $needsElevation = $true
        }
    }

    # Wait for processes to terminate
    Start-Sleep -Milliseconds 500

    # Check if we need elevation retry
    $stillRunning = @()
    foreach ($proc in $processesToKill) {
        if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
            $stillRunning += $proc
        }
    }

    # If processes still running, retry with elevation
    if ($stillRunning -and -not $needsElevation) {
        Write-Host "`nSome processes still running. Attempting with administrator privileges..." -ForegroundColor Yellow -NoNewline

        try {
            $procIds = $stillRunning.Id -join ','
            
            $elevationScript = @"
Get-Process -Id ($procIds) -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
"@

            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command `"$elevationScript`"" -Verb RunAs -Wait -NoNewWindow -ErrorAction SilentlyContinue
            
            Write-Host "`nElevation attempt completed." -ForegroundColor Green -NoNewline
        }
        catch {
            Write-Host "`n✗ Failed to elevate privileges: $_" -ForegroundColor Red -NoNewline
            Write-Host "`n  Please manually close the application before uninstalling." -ForegroundColor Yellow -NoNewline
        }
    }
    elseif ($stillRunning) {
        $procNames = $stillRunning.ProcessName -join ', '
        Write-Host "`n✗ Could not terminate all processes." -ForegroundColor Red -NoNewline
        Write-Host "`n  Please manually close: $procNames" -ForegroundColor Yellow -NoNewline
    }
    else {
        Write-Host "`n✓ All processes terminated successfully." -ForegroundColor Green -NoNewline
    }
}
