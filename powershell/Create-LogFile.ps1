<#
.SYNOPSIS
    Creates a log file at the specified path with timestamped entries.

.DESCRIPTION
    This script creates a log file either at a specified path with a given filename or 
    generates a timestamped filename in the specified directory. It provides functions 
    to create and write timestamped log entries to the file.

.PARAMETER path
    The path where the log file should be created. If -isFile is not specified, this 
    parameter is treated as a directory path and a timestamped filename is generated.
    If -isFile is specified, this parameter should include the full path with filename.

.PARAMETER isFile
    Switch parameter that determines how the path parameter is interpreted:
    - If not specified: path is treated as a directory and generates a timestamped filename
    - If specified: path is treated as a complete file path including filename

.EXAMPLE
    .\Create--LogFile.ps1 -path "C:\Logs"
    Creates a log file with auto-generated name (dummy_yyyyMMdd_HHmmss.log) in C:\Logs directory

.EXAMPLE
    .\Create-LogFile.ps1 -path "C:\Logs\mylog.log" -isFile
    Creates a log file named mylog.log in C:\Logs directory

.NOTES
    File Name      : CreateLogFile.ps1
    Prerequisite   : PowerShell 5.1 or later
    Author         : jaehoo
#>
param (
        [Parameter(Mandatory, HelpMessage = "Enter the output path to create log")]
        [Alias('o')] [string]$path,
        [Alias('f')] [switch]$isFile
    )


function CreateLogFile {
    param([string]$path)

    $logDateTime = Get-Date -Format "yyyyMMdd_HHmmss"

    if($isFile){
        $outputPath = Split-Path -Path $path
        $fileName = Split-Path -Path $path -Leaf
    }
    else{
        $outputPath = $path
        $fileName = "dummy_$logDateTime.log"
    }

    # Create directories if they don't exist
    $resolvedPath = (New-Item -ItemType Directory -Force -Path $outputPath).FullName
    return Join-Path -Path $resolvedPath -ChildPath $fileName
}

function log{
    param([string]$text)
    Write-Output "$(Get-Date -Format "HH:mm:ss.fff") - $text" | Add-Content -Path $logFile 
}


$logFile = CreateLogFile -path $path

log "Starting process..."
log "Dummy entry 1"
log "End process"

Write-Host "log created: $logFile" -ForegroundColor Blue
