# Module Name
$ModuleName = "ManageToDo"

# Module Path
if(($PSVersionTable.Platform -eq "Win32NT") -or ($PSVersionTable.Platform -eq $null)){
	$ModulePath = Join-Path (Split-Path $PROFILE -Parent) "Modules"
}
else{
	$ModulePath = Join-Path ($env:HOME) "/.local/share/powershell/Modules"
}
$RemovePath = Join-Path $ModulePath $ModuleName

# Remove Direcory
if( Test-Path $RemovePath ){
	Remove-Item $RemovePath -Force -Recurse
}

$ApDir = Join-Path $env:LOCALAPPDATA 'InterruptToDo'
$ApFile = Join-Path $ApDir 'ToDoTasks.json'

if( Test-Path $ApFile ){
	Remove-Item $ApFile
}

if( Test-Path $ApDir ){
	Remove-Item $ApDir -Force -Recurse
}
