<#
.SYNOPSIS
Script to replace tag names into xml files.

.DESCRIPTION
This script is designed to replace the xml tags into xml file using 
xpath expressions.

IMPORTANT: Edit the script before to use it, set the tags to be 
replaced into $replacementEntries variable. It requeries the xpath
expression and the keypair of tags defined as following example:

$replacementEntries = @{
    "//*[local-name()='body']" = 
        @{
            "List"="ProductList"
        }
    "//ProductList" = 
        @{
            "items"="products"
        }
}


.PARAMETER sourcePath
-s, file system path to file or directory.

.PARAMETER allDirs
-a, to read all xml files that are located in the first child directories into the path.

.INPUTS
File paths to xml files

.OUTPUTS
Xml files modified, the same taken from intpu

.EXAMPLE
.\Replace-XmlTags.ps1 -s "C:\Path\To\File"
This example shows how to replace tags in a xml file

.EXAMPLE
.\Replace-XmlTags.ps1 -s "C:\Path\To\Directory"
This example shows how to replace tags into all xml files contained in a directory

.EXAMPLE
.\Replace-XmlTags.ps1 -s "C:\Path\To\Directory" -a
This example shows how to replace tags into all xml files that are contained into the all
child directories from the directory path. 

This only reads the first level of subdirectories is not a recursive read.

.NOTES
Author: Jaehoo
Date: 2024-08-23
#>
param (
        [Parameter(Mandatory, HelpMessage = "Enter the path to file or directory.")]
        [Alias('s')] [string]$sourcePath,
        [Alias('a')] [switch]$allDirs
    )

<#
 Xpath expressions and the tags to be replaced into xml document
#>
$replacementEntries = @{
    "//*[local-name()='SingleREquest']" = 
        @{
            "body"="ProductList"
        }
    "//ProductList" = 
        @{
            "items"="products"
        }
    "//ProductList/tags" = 
        @{
            "tag"="el"
        }
    
    "//ProductList/products/item" = 
        @{
            "name"="FINAME"
            "value"="FIVALUE"
        }
}


<#
.DESCRIPTION
Read the xml content of a file to replace the defined tags into the file.

.PARAMETER sourcePath
Source path to file

.PARAMETER replacements
A hastable collection of replacement configuraction (xpath expressions and keypair of tags)

.EXAMPLE
replaceTags-sourcePath "C:\Path\To\File" -replacements @{ "//body" = @{"NAME"="NAME_1"}}
#>
function replaceTags {
    param (
        [string]$sourcePath,
        [hashtable]$replacements        
    )

    [xml]$document = Get-Content -Path $sourcePath

    $docHashcode = calculateHashCode -document $document

    # read tags replacements to be applied on file
    $entries = $replacements.GetEnumerator() | Sort-Object Name

     # replace tags on each node 
     foreach ($entry in $entries){

        $nodeItems = $document.SelectNodes($entry.Key)

        $tagsToReplace = $entry.Value.GetEnumerator() | Sort-Object Name

        replaceTagsInNodes -document $document -nodeItems $nodeItems -tagsToReplace $tagsToReplace
     }

     
     
     $newHashCode = calculateHashCode -document $document
     

    if($docHashcode -ne $newHashCode){
        
         saveFile -document $document -outputFile $sourcePath
        # $fileContent.Save($sourcePath)
        
        Write-Host "$sourcePath - replacemnets made"
    }
    else{
        Write-Host "$sourcePath - no changes"
    }
    

}

function calculateHashCode{
    param(
        [System.Xml.XmlDocument]$document
    )

    $hashCode = [System.BitConverter]::ToString([System.Security.Cryptography.HashAlgorithm]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($document.OuterXml)))

    # Write-Host "hashcode: $($hashCode)"
    
    return $hashCode

}

function saveFile{
    param(
        [System.Xml.XmlDocument]$document,
        [string]$outputFile
    )

    # Create XmlWriterSettings to control the output format
    $xmlSettings = New-Object System.Xml.XmlWriterSettings
    $xmlSettings.Indent = $true  # Disable indentation
    $xmlSettings.NewLineHandling = [System.Xml.NewLineHandling]::None  # Prevent new lines

    # Create an XmlWriter with the specified settings
    $xmlWriter = [System.Xml.XmlWriter]::Create($outputFile, $xmlSettings)

    # Write the modified XML to the XmlWriter
    $document.Save($xmlWriter)

    # Flush and dispose of the writer
    $xmlWriter.Flush()
    $xmlWriter.Dispose()

}


<#
.DESCRIPTION
Replace the tag names of an xml file using xpath expressions, it could replace multiple lines in a node

.PARAMETER document
Xml document content where the will be replaced

.PARAMETER nodeItems
An array of System.Xml.XmlNode objects where the changes will be made

.PARAMETER tagsToReplace
A hashtable with a keypair of tag names, the search tag and the other to replace it

.EXAMPLE
replaceNodes -document $document -nodeItems $nodeItems -tagsToReplace @{"NAME"="NAME_1"}
#>
function replaceTagsInNodes{
    param (
        [System.Xml.XmlDocument]$document,
        [array]$nodeItems,
        [array]$tagsToReplace
    )

    foreach($item in $nodeItems){

        # iterate tags to replace in every item
            foreach ($tag in $tagsToReplace){
                nodeReplacement -document $document -nodes $item.SelectNodes($tag.Key) -newNodeName $tag.Value
                
            }
    }

}

function nodeReplacement{
    param(
        [System.Xml.XmlDocument]$document,
        [array]$nodes,
        [string]$newNodeName
    )

    foreach($node in $nodes){
        
        if ($null -ne $node) {

            $newNode = $document.CreateElement($newNodeName)  
            $newNode.InnerXml = $node.InnerXml 
            
            # replace old tag with new tag (console output is suppressed)
            # ($node.ParentNode.ReplaceChild($newNode, $node)) > $null
            $node.ParentNode.ReplaceChild($newNode, $node) | Out-Null
        }
    }
}



function replaceTagsByDirectory{
    param(
        [string]$sourcePath,
        [hashtable]$replacements 
    )

    Write-Host "`n Replacing tags into: $sourcePath"
    Write-Host "-----------------------"

    Get-ChildItem -Path $sourcePath -Filter "*.xml" | ForEach-Object {
        #Write-Host $_.FullName
        # Replace tags in a specific file
        replaceTags -sourcePath $_.FullName -replacements $replacementEntries

    }
    
}

function replaceTagsByDirectories{
    param(
        [string]$sourcePath,
        [hashtable]$replacements 
    )
    
    $directories = Get-ChildItem -Path $sourcePath -Directory

    foreach($directory in $directories){
        replaceTagsByDirectory -sourcePath $directory.FullName -replacements $replacements
    }

}


$fullPath = Resolve-Path -Path $sourcePath

    if (Test-Path -Path $fullPath -PathType Leaf) { 
        # Replace tags in a specific file
        replaceTags -sourcePath $fullPath -replacements $replacementEntries

    } 
    elseif (Test-Path -Path $fullPath -PathType Container) {

        if($allDirs){
            replaceTagsByDirectories -sourcePath $fullPath -replacements $replacementEntries
        }else{
            # Replace tags in files contained in a directory
            replaceTagsByDirectory -sourcePath $fullPath -replacements $replacementEntries
        }
        

    } else {
        throw "$_ is not a file or directory. Please validate if it exists."
        exit
    }
