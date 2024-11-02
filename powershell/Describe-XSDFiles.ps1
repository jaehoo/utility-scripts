
<#
.SYNOPSIS
    Parses XSD schema files and generates a structured text output describing the schema elements.

.DESCRIPTION
    This script analyzes XML Schema Definition (XSD) files and creates a corresponding text file 
    that describes the structure, including elements, types, documentation, and occurrence constraints.
    It can process either a single XSD file or all XSD files in a directory.

.PARAMETER Path
    The path to either a single XSD file or a directory containing XSD files.
    This parameter is mandatory.

.PARAMETER recursive
    Switch parameter to enable recursive processing of subdirectories when Path points to a directory.
    This parameter is optional.

.EXAMPLE
    .\Describe-XSDFiles.ps1 -Path "C:\Schemas\sample.xsd"
    Processes a single XSD file and generates a corresponding .txt file with the schema description.

.EXAMPLE
    .\Describe-XSDFiles.ps1 -Path "C:\Schemas" -recursive
    Processes all XSD files in the specified directory and its subdirectories.

.EXAMPLE
    .\Describe-XSDFiles.ps1 -in "C:\Schemas\sample.xsd"
    Using the alias 'in' for the Path parameter to process a single XSD file.

.OUTPUTS
    Creates text files with the same name as the input XSD files but with .txt extension.
    Each output file contains a pipe-delimited description of the schema elements with the following columns:
    - Element path
    - Description
    - Data type
    - Maximum length
    - Minimum occurrences
    - Maximum occurrences

.NOTES
    File Name      : Describe-XSDFiles.ps1
    Prerequisite   : PowerShell 5.1 or later
    Dependencies   : System.Xml assembly
    Author         : jaehoo
#>
param (
    [Parameter(Mandatory, HelpMessage = "Enter the path to file or directory")]
    [Alias('in')] [string]$Path,
    [Alias('r')] [switch]$recursive
)

Add-Type -AssemblyName System.Xml



#===============================

function isDirectory{
    param(
        [ValidateScript({ Test-Path $_ })]
        [string]$path
        )

        $isDir = (Get-Item $path).PSIsContainer
        if ($isDir) {
            Write-Output "$path is a directory."
        } else {
            Write-Output "$path is a file."
        }

        return $isDir

}

function readSequence {
    param (
        [System.Xml.XmlElement]$sequence,
        [string]$prefix
    )
    
    #$row = @()
    $outputText += "$prefix|desc|type|maxLength|minOccurs|maxOccurs|`n"

    foreach($item in $sequence.ChildNodes){

        $entry = @{}

        if($item.ComplexType){
            readSequence -sequence $item.ComplexType.Sequence -prefix "$prefix/$($item.Name)"
        }

        #$entry.Add("path", $prefix)

        if($item.LocalName -eq "element"){

            if($item.Annotation.Documentation){
                $entry.Add('desc', $item.Annotation.Documentation)
            }

            if($item.Name){
                $entry.Add('name', $item.Name)
            }
            
            if($item.Type){
                if($item.Type.StartsWith("xsd:")){
                    $entry.Add('type', $item.Type.Substring(4))
                }else{
                    #search complex type
                    $entry.Add('type', $item.Type)
                    $xpathExp =  "//xsd:complexType[@name='$($item.Type)']"
                   $nestedItem = $document.SelectSingleNode($xpathExp, $namespaceManager)

                   $entry.Add('desc', $nestedItem.Annotation.Documentation)
                }

                  
            }
            else{

                if($item.SimpleType){
                    $entry.Add('type', $item.SimpleType.Restriction.Base.Substring(4)) 
                    $entry.Add('length', $item.SimpleType.Restriction.MaxLength.Value)
                }

            }

            if(-not $null -eq $item.minOccurs){
                $entry.Add('min', $item.minOccurs)
            }
            
            if(-not $null -eq $item.maxOccurs){
                $entry.Add('max', $item.maxOccurs)
            }
            
            
        }
        #Write-Output $entry.Name

        $outputText += "$($entry.Name)|$($entry.desc)|$($entry.type)|$($entry.length)|$($entry.min)|$($entry.max)|`n"
        
        # Append the line to the text file
       

    }

    return $outputText
    


}


function printEntries{
    param([array]$row)

    foreach($r in $row){

        foreach ($key in $r.Keys) {
            $value = $r[$key]
            Write-Host "Key: $key, Value: $value"
        }
    }
}


function readFile{
    param([System.IO.FileSystemInfo]$path)

    $outputFilePath = [System.IO.Path]::ChangeExtension($path.FullName, ".txt") 
    New-Item -Path $outputFilePath -ItemType File -Force | Out-Null

    # Load the XSD file into an XML object
    $xsdPath = (Get-Item -Path $path).FullName
    [xml]$document = Get-Content -Path $xsdPath

    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $namespaceManager.AddNamespace("xsd", "http://www.w3.org/2001/XMLSchema") 

    
    $childs = $document.Schema.ChildNodes 

    foreach($el in $childs){

        #Write-Host $el.Name 
    
        if($el.LocalName -eq "element"){
            $outputText =  readSequence -sequence $el.complexType.Sequence -prefix "/$($el.Name)"
        }
        elseif($el.LocalName -eq "complexType"){
            $outputText = readSequence -sequence $el.Sequence -prefix "/$($el.Name)"
        }
    
    
    }

    #Write-Host $outputFilePath
    Add-Content -Path $outputFilePath -Value $outputText 
    Write-Host (Split-Path $outputFilePath -Leaf) -ForegroundColor Blue
    

}

function readDirectory{
    param([System.IO.FileSystemInfo]$Path)

    $files = Get-ChildItem -Path $Path.FullName -Filter "*.xsd"

    Write-Host "Reding [$($files.Count)] files from: $($Path.FullName)`n" -ForegroundColor Yellow

    foreach ($file in $files) {
        Write-Host $file.Name -ForegroundColor Cyan
        #Write-Host $file.GetType()
        readFile -path (Get-Item -Path $file.FullName)
    }
}


# Read directory files or a file
if($(isDirectory $Path) -eq $true){ 
    readDirectory -Path (Get-Item -Path $Path)
}
else{ 
    readFile -path (Get-Item -Path $Path)
}

