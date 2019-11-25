Param(
    $vsts_URL,
    $agent_Pool,
    $agent_Name,
    $pat_Token,
    $agent_Tag,
    $cosmosDb_Key
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
    Write-Verbose ("Error: {0}" -f $Error[0].Exception)
}

Write-Verbose("start script")
Write-Verbose("vstsURL: $vsts_URL")
Write-Verbose("agentPool: $agent_Pool")
Write-Verbose("agentName: $agent_Name")
Write-Verbose("agenttag: $agent_Tag")


Set-ExecutionPolicy Bypass -Scope Process -Force;

#Install dotnet core, nodejs and npm with chocolatey
Write-Verbose("install chocholatey")
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));
choco feature enable -n allowGlobalConfirmation;

Write-Verbose("install dotnetcore the latest")
choco install dotnetcore-sdk -y;

Write-Verbose("install dotnetcore 2.2")
choco install dotnetcore-sdk --version=2.2 -force -y;

Write-Verbose("install nodejs")
choco install nodejs -y;

Write-Verbose("install webdeploy")
choco install webdeploy -y;

Write-Verbose("install java")
choco install javaruntime -y;

Write-Verbose("install build agent")
choco install azure-pipelines-agent --params "'/AgentName:$agent_Name /Directory:c:\agent /Url:$vsts_URL /Token:$pat_Token /Pool:$agent_Pool /Replace'"

Write-Verbose("download Cosmos DB Emulator")

$downloadDirectory = Join-Path $env:SystemDrive 'CosmosDBEmulator'
New-Item -Path $downloadDirectory -ItemType Directory -force | Out-Null

$clnt = new-object System.Net.WebClient
$url = "https://aka.ms/cosmosdb-emulator"
$file = Join-Path $downloadDirectory ("AzureCosmosDB.Emulator.msi")
$clnt.DownloadFile($url, $file)

# Install the MSI
Write-Verbose("install Cosmos DB Emulator")
Start-Process 'msiexec.exe' -ArgumentList '/i', $file,'/qn' -Wait
Write-Verbose("installer done")

Write-Verbose("create a startup job for the Cosmos DB Emulator")
# It is a good idea to specify a random delay period of 30 seconds to one a minute to help 
# to avoid race conditions at startup. This will also help ensure a greater chance of success for the job.
# https://devblogs.microsoft.com/scripting/use-powershell-to-create-job-that-runs-at-startup/
$RunCosmosDbEmulatorScriptBlock = [ScriptBlock]::Create("Start-Process ""c:\Program Files\Azure Cosmos DB Emulator\CosmosDB.Emulator.exe"" -ArgumentList '/noui', '/AllowNetworkAccess', '/NoFirewall', '/NoExplorer', '/Key=$cosmosDb_Key'")
$action = New-ScheduledTaskAction –Execute "$pshome\powershell.exe" -Argument  "$RunCosmosDbEmulatorScriptBlock; quit"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:00:30
Register-ScheduledTask -TaskName StartCosmosDBEmulatorOnStartup -Action $action -Trigger $trigger -RunLevel Highest -User "nt authority\localservice"

Write-Verbose("schedule a reboot in a minute")
# Restart VM using a job as per recommendation here https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows
$RestartTrigger = New-JobTrigger -Once -At (Get-Date).AddMinutes(1)
Register-ScheduledJob -Name RestartInMinute -Trigger $RestartTrigger -ScriptBlock { Restart-Computer }