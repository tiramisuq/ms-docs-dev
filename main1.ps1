$status=""
$errorMessage=""
$errorInfo=""
$result=""
$timestamp=Get-Date -Format o
try
{
	"Execute scripts....".toString()
  ./run1.ps1
  "Succeeded no exception".toString()
  $status="Succeeded"
}
catch
{
  "Fail with exception".toString()
  $errorMessage=$_
  Write-Warning "Error: $_"
  $status="Failed"
  $errorInfo=@"
  {
    		"code": "DocBuildFailure",
    		"log_url": "https://apidrop.visualstudio.com/Content%20CI/_build/results?buildId=RUNID&view=logs&j=todo",
    		"message": "$errorMessage",
    		"callstack": ""
  			}
"@
} finally {
	Write-Output "Compose error message if any: $errorMessage"
	"Compose result...".toString()
	$result=@"
	{
  		"stage": "RestBuild",
  		"status": "$status",
  		"branch": "openapiHub_preproduction_todoID",
 		"timestamp": "$timestamp",
  		"repository_info": {
     		"repository_name": "AzureRestPreview"
  		},
  		"error": [
  			$errorInfo
  		]
	}
"@
	$result=$result -replace "\\", "/"
	$info = ConvertFrom-Json -InputObject $result
	$info.error
}

$ehName = "dev-test-hub" # hub name
$ehNameSpace = "openapi-hub-docs-events-devsh" # namespace
$Access_Policy_Name = "docMsg" # name of the policy
$Access_Policy_Key = $Env:ASA_KEY

[Reflection.Assembly]::LoadWithPartialName("System.Web")| out-null
$URI = "{0}.servicebus.windows.net/{1}" -f @($ehNameSpace,$ehName)

#Token expires now+300
$Expires=([DateTimeOffset]::Now.ToUnixTimeSeconds())+300
$SignatureString=[System.Web.HttpUtility]::UrlEncode($URI)+ "`n" + [string]$Expires
$HMAC = New-Object System.Security.Cryptography.HMACSHA256
$HMAC.key = [Text.Encoding]::ASCII.GetBytes($Access_Policy_Key)
$Signature = $HMAC.ComputeHash([Text.Encoding]::ASCII.GetBytes($SignatureString))
$Signature = [Convert]::ToBase64String($Signature)
$SASToken = "SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($URI) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($Signature) + "&se=" + $Expires + "&skn=" + $Access_Policy_Name

# create Request Body

# API headers
#
$headers = @{
            "Authorization"=$SASToken;
            "Content-Type"="application/atom+xml;type=entry;charset=utf-8"; # must be this
            "Content-Length" = ("{0}" -f ($result.Length));
            "eventHubConnectionString"="Endpoint=sb://openapi-hub-docs-events-devsh.servicebus.windows.net/;SharedAccessKeyName=docMsg;SharedAccessKey=$Access_Policy_Key;EntityPath=dev-test-hub"
            }
$headers | ConvertTo-Json

# execute the Azure REST API
$method = "POST"
$dest = 'https://' +$URI  +'/messages?timeout=60&api-version=2014-01'
"Sendging message to event hub...".toString()
$response=Invoke-WebRequest -Uri $dest -Method $method -Headers $headers -Body $result -Verbose
$response 