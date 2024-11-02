<#
.SYNOPSIS
    Combines multiple CSV files into a single CSV file.

.DESCRIPTION.\
    This script takes a source directory path containing CSV files and combines all CSV files 
    found in that directory into a single output CSV file. The script preserves the header 
    from the first CSV file and combines all data rows from all CSV files.

.PARAMETER sourcePath
    The directory path containing the CSV files to be combined.
    This parameter is mandatory.

.PARAMETER outputFile
    Switch parameter to specify if an output file should be created.
    If not specified, the combined data will be output to the pipeline.

.EXAMPLE
    .\Merge-CSVFiles.ps1 -sourcePath "C:\Data\CSVFiles"
    Combines all CSV files in the C:\Data\CSVFiles directory and outputs the result to the pipeline.

.EXAMPLE
    .\Merge-CSVFiles.ps1 -i "C:\Data\CSVFiles" -o
    Using aliases, combines all CSV files in the specified directory and creates an output file.

.NOTES
    File Name      : Merge-CSVFiles.ps1
    Prerequisite   : PowerShell 5.1 or later
    Author         : jaehoo
#>
param (
        [Parameter(Mandatory, HelpMessage = "Enter the directory path that contains csv files")]
        [Alias('i')] [string]$sourcePath,
        [Alias('o')] [string]$outputFile
    )

$csvFiles = Get-ChildItem -Path $sourcePath -Filter *.csv 

# Check if any CSV files were found
if ($csvFiles.Count -eq 0) {
    Write-Warning "No CSV files found in $sourcePath"
    exit
}

$csvFiles| ForEach-Object { 
    Write-Host $_.Name
    $currentData += Import-Csv -Path $_.FullName
}

if(-not $outputFile -or $null -eq $outputFile){
    $outputFile = $sourcePath +"\output.txt"
    Write-Host "out: $outputFile" -ForegroundColor Yellow
}


$currentData | Export-Csv -Path $outputFile -NoTypeInformation