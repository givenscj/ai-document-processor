Param (
  [Parameter(Mandatory = $true)]
  [string]
  $azureTenantID,

  [string]
  $azureSubscriptionID,

  [string]
  $AzureResourceGroupName,

  [string]
  $AzdEnvName
)

Start-Transcript -Path C:\WindowsAzure\Logs\CMFAI_CustomScriptExtension.txt -Append

[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

write-host "Installing Visual Studio Code";
choco upgrade vscode -y --ignoredetectedreboot --force

write-host "Installing Azure CLI";
choco upgrade azure-cli -y --ignoredetectedreboot --force

write-host "Installing GIT";
choco upgrade git -y --ignoredetectedreboot --force

write-host "Installing NODEJS";
choco upgrade nodejs -y --ignoredetectedreboot --force

write-host "Installing Python311";
choco install python311 -y --ignoredetectedreboot --force
#choco install visualstudio2022enterprise -y --ignoredetectedreboot --force
write-host "Installing AZD";
choco install azd -y --ignoredetectedreboot --force --version 1.14.100

write-host "Installing Powershell Core";
choco install powershell-core -y --ignoredetectedreboot --force

write-host "Installing Chrome";
#choco install googlechrome -y --ignoredetectedreboot --force

write-host "Installing Notepad++";
choco install notepadplusplus -y --ignoredetectedreboot --force

write-host "Installing Github Desktop";
choco install github-desktop -y --ignoredetectedreboot --force

#install extenstions
Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension","ms-azuretools.vscode-bicep","--force" -wait
Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension","ms-azuretools.vscode-azurefunctions","--force" -wait
Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension","ms-python.python","--force" -wait

write-host "Updating WSL";
wsl.exe --update

write-host "Downloading repository";
mkdir C:\github -ea SilentlyContinue
cd C:\github
git clone https://github.com/azure/ai-document-processor
#git checkout cjg-zta
cd ai-document-processor

git config --global --add safe.directory C:/github/ai-document-processor

#add azd to path
$env:Path += ";C:\Program Files\Azure Dev CLI"

write-host "Logging into Azure CLI and AZD";
az login --identity --tenant $azureTenantID
azd auth login --managed-identity --tenant-id $azureTenantID

write-host "Installing NPM packages";
npm install -g @azure/static-web-apps-cli
npm install -g typescript

write-host "Initializing AZD";
azd init -e $AzdEnvName

write-host "Restarting the machine to complete installation";
shutdown /r

Stop-Transcript