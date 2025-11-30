# Remove data
$ApFile = Join-Path $ApDir 'ToDoTasks.json'
if( Test-Path $ApFile ){
	Remove-Item $ApFile
}

$ApDir = Join-Path $env:LOCALAPPDATA 'InterruptToDo'
if( Test-Path $ApDir ){
	Remove-Item $ApDir
}
