# Online installer

$ModuleName = "ManageToDo"
$GitHubName = "MuraAtVwnet"

$HomeDirectory = "~/"
$Module = $ModuleName + ".psm1"
$Installer = "Install" + $ModuleName + ".ps1"
$UnInstaller = "UnInstall" + $ModuleName + ".ps1"
$Vertion = "Vertion" + $ModuleName + ".txt"
$GithubCommonURI = "https://raw.githubusercontent.com/$GitHubName/$ModuleName/master/"
$OnlineInstaller = $HomeDirectory + "OnlineInstall.ps1"

$URI = $GithubCommonURI + $Module
$ModuleFile = $HomeDirectory + $Module
Invoke-WebRequest -Uri $URI -OutFile $ModuleFile

$URI = $GithubCommonURI + "install.ps1"
$InstallerFile = $HomeDirectory + $Installer
Invoke-WebRequest -Uri $URI -OutFile $InstallerFile

$URI = $GithubCommonURI + "uninstall.ps1"
$OutFile = $HomeDirectory + $UnInstaller
Invoke-WebRequest -Uri $URI -OutFile $OutFile

$URI = $GithubCommonURI + "Vertion.txt"
$OutFile = $HomeDirectory + $Vertion
Invoke-WebRequest -Uri $URI -OutFile $OutFile

& $InstallerFile

Remove-Item $ModuleFile
Remove-Item $InstallerFile
Remove-Item $OnlineInstaller

