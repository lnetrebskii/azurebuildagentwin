Param(
    $vsts_URL,
    $agent_Pool,
    $agent_Name,
    $pat_Token,
    $agent_Tag
)

$tmpFile = "C:\arrangeAgent.log"
New-Item -ItemType File -Path $tmpFile -Force | Out-Null


Function Write-Verbose {
    Param (
        [string]$message
    )

    $messageWithData = "$((Get-Date).ToString()): $message"
    Add-content $tmpFile -value $messageWithData
}

trap {
    WriteLog ("Error: {0}" -f $Error[0].Exception)
}

WriteLog("start script")
WriteLog("vstsURL: $vsts_URL")
WriteLog("agentPool: $agent_Pool")
WriteLog("agentName: $agent_Name")
WriteLog("agenttag: $agent_Tag")


Set-ExecutionPolicy Bypass -Scope Process -Force;

#Install dotnet core, nodejs and npm with chocolatey
WriteLog("install chocholatey")
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));
choco feature enable -n allowGlobalConfirmation;

WriteLog("install dotnetcore 2.2")
choco install dotnetcore-sdk --version=2.2 -y;

WriteLog("install dotnetcore the latest")
choco install dotnetcore-sdk -y;

WriteLog("install nodejs")
choco install nodejs -y;

WriteLog("install webdeploy")
choco install webdeploy -y;

WriteLog("install java")
choco install webdeploy -y;

WriteLog("download buildagent")

$downloadDirectory = Join-Path $env:SystemDrive 'agent'
New-Item -Path $downloadDirectory -ItemType Directory -force | Out-Null

$clnt = new-object System.Net.WebClient
$url = "https://vstsagentpackage.azureedge.net/agent/2.146.0/vsts-agent-win-x64-2.146.0.zip"
$file = Join-Path $downloadDirectory ([System.IO.Path]::GetFileName($url))
$clnt.DownloadFile($url, $file)

WriteLog("expand build agent")
Expand-Archive -Path $file -DestinationPath $downloadDirectory

WriteLog("install build agent")
# Replaces agent with the same name in the same pool
# Agent starts with Windows Login
# Agent works as a service
$agentoutput = C:/agent/bin/Agent.Listener.exe configure --url $vsts_URL --agent $agent_Name --pool $agent_Pool  --unattended --auth pat --token $pat_Token  --windowsLogonAccount "NT AUTHORITY\SYSTEM" --replace --runAsService --runAsAutoLogon

WriteLog($agentoutput)

Restart-Computer