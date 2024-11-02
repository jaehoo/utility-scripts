<# 
.SYNOPSIS
Send payload file(s) to defined  webservice with basic authentication

.DESCRIPTION
This PowerShell script send a single file, multple files contained int a directory or the nested files in a directory.
It supports recursive directory traversal and provides detailed output on successful and failed file transfers.

.PARAMETER Path
The path to the file or directory to send. (Mandatory)

.PARAMETER user
The username to use for authentication. (Mandatory)

.PARAMETER pass
The password to use for authentication. (Optional)

.PARAMETER endpoint
The URL of the webservice to send the files to. (Mandatory)

.PARAMETER recursive
A switch to enable recursive directory traversal. (Optional)

.OUTPUTS
Returns a result object with the number of successful and failed file transfers.

.EXAMPLE
.\Make-ResquestToWebService.ps1 -Path "C:\file.xml" -user "username" -pass "password" -endpoint "https://webservice.com/upload"
This example shows howto send a single file to the webservice. The password could be ommited.

.EXAMPLE
.\Make-ResquestToWebService.ps1 -Path "C:\directory" -user "username" -pass "password" -endpoint "https://webservice.com/upload"
This example shows howto send all files from defined directory to the webservice recursively. The password could be ommited.

.EXAMPLE
.\Make-ResquestToWebService.ps1 -Path "C:\directory" -user "username" -pass "password" -endpoint "https://webservice.com/upload" -recursive
This example shows howto send all nested files from defined directory to the webservice recursively. The password could be ommited.

.NOTES
Author: Jaehoo
Date: 2024-09-25
#>
param (
    [Parameter(Mandatory, HelpMessage = "Enter the path to file or directory")]
    [Alias('in')] [string]$Path,
    [Parameter(Mandatory, HelpMessage = "Enter the username")]
    [Alias('u')] [string]$user,
    [Parameter(HelpMessage = "Enter the password")]
    [Alias('p')] [string]$pass,
    [Parameter(Mandatory, HelpMessage = "Enter the webservice url")]
    [Alias('url')] [string]$endpoint,
    [Alias('r')] [switch]$recursive
)

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

function userConfirmation{

    # Prompt the user for input
    $userInput = Read-Host "Are you sure to send data to this server: (Y/N)"
    
    if ($userInput -eq 'Y' -or $userInput -eq 'y') {
        Write-Host "Sending data"
        
    } elseif ($userInput -eq 'N' -or $userInput -eq 'n') {
        Write-Host "Execution cancelled."
        exit
    }
}


function sendFile{
    param(
        [string]$username,
        [string]$pass,
        [string]$url,
        [System.IO.FileSystemInfo]$file
        )
    
    $securePassword  = ConvertTo-SecureString $pass -AsPlainText -Force
    $basicCredentials = New-Object System.Management.Automation.PSCredential($username, $securePassword)

    $headers = @{ "Content-Type" = "text/xml"}
    
    $params = @{
        Uri         = "$url"
        Headers     = $headers
        Credential  = $basicCredentials
        Method      = "Post"
        Body        = (Get-Content -Path $($file.FullName) -Raw)

    }

    return Invoke-WebRequest @params 
    
}

function sendFiles{
    param(
        [string]$username,
        [string]$pass,
        [string]$url,
        [System.IO.FileSystemInfo]$path
    )

    Write-Host "-------------------------------------------"
    
    $files = Get-ChildItem -Path $path.FullName -Filter "*.xml"

    Write-Host "Sending files: {$($files.Count)} from: $directory`n" -ForegroundColor Yellow

        $badResponses = New-Object System.Collections.ArrayList
        $badResponses.Clear()
        $counter = 0
        $errors = 0

        foreach ($file in $files) {
            
            try {
                
                $response = sendFile -username $username -pass $pass -url $url -file $file
                Write-Host $file.FullName
                
                if ($response -and $response.StatusCode -eq 200) {
                    $counter++
                    
                }
                else{
                    $errors++
                    $badResponses.Add($response)
                }

            } catch {
                
                Write-Host "$($file.FullName) - err"
                if ($_.Exception.Response.StatusCode -eq 500) {
                    Write-Host $_
                    #Write-Host "Caught an HTTP 500 error."
                    $errorContent = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($errorContent)
                    $responseBody = $reader.ReadToEnd()
                    #Write-Host "Response Body: $responseBody"
                    $badResponses.Add($responseBody)

                }

                $errors++
                
            }
        }

        
        $result = @{
            succed = $counter
            errors = $errors
            badResponses = $badResponses
        }
        
        return $result


}

function printSummary{
    param([array]$result)
    #Write-Host "-------------------------"
    Write-Host "`n[success: $($result.succed), errors: $($result.errors), bad responses: $($result.badResponses.Count)] `n" -ForegroundColor DarkBlue
    
}
function sendPayloadByDirectory{
    param(
        [string]$username,
        [string]$pass,
        [string]$url,
        [System.IO.FileSystemInfo]$directory,
        [bool]$recursive
    )

    if($recursive){
        
        
        # Send files from parent directory
        $result = sendFiles -username $username -pass $pass -url $url -path $directory
        printSummary -result $result

        # Send files from sub directories
        $directories = Get-ChildItem -Path $directory -Directory
        
        foreach ($dir in $directories) {

            $params = @{
                username = $user
                pass = $pass
                url =  $url
                directory = (Get-Item -Path $dir.FullName)
                recursive = $recursive
            }
        
            $result = sendPayloadByDirectory @params

        }

    }
    else{
        
        
        $result = sendFiles -username $username -pass $pass -url $url -path $directory
        printSummary -result $result

    }

}

userConfirmation

if (-not $PSBoundParameters.ContainsKey("pass")) {
    Write-Host "Param1 exists";
    $securePassword = Read-Host "Enter your password" -AsSecureString
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )

    #Write-Host "Your password is: $plainPassword" -ForegroundColor Yellow
    $pass = $plainPassword
    
} 

if($(isDirectory $Path) -eq $true){
    
    $params = @{
        username = $user
        pass = $pass
        url = $endpoint
        directory = (Get-Item -Path $Path)
        recursive = $recursive
    }

    $result = sendPayloadByDirectory @params 

    
}
else{
    
    $response = sendFile -username $user -pass $pass -url $endpoint -file (Get-Item -Path $Path)
    
    Write-Host "Response code: $($response.StatusCode) $($response.Headers["Content-Type"])"
    Write-Host $response.Content
}
