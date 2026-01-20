<#
.SYNOPSIS
Downloads trusted employee report PDFs from the RHRIS system.

.PARAMETER Server
The server environment to connect to (Production or Testing).

.PARAMETER Credential
Credentials for authenticating with the RHRIS system.

.PARAMETER Directory
Directory where PDF reports will be saved.

.PARAMETER FileNo
One or more file numbers to retrieve reports.

.EXAMPLE
$Credential = [pscredential]::new($Env:TRUSTED_EMPLOYEE_USERNAME,($Env:TRUSTED_EMPLOYEE_PASSWORD| ConvertTo-SecureString -AsPlainText -Force))

'59AC46','3A9804' | Get-TrustedEmployeeReport -Server Production -Credential $Credential -Directory '~/Desktop/Trusted Employee'
#>
function Get-TrustedEmployeeReport {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Production','Testing')]
        [string]$Server,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$FileNo
    )

    begin {

        $Directory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Directory)

        if ( -not (Test-Path $Directory) ) {
            New-Item -ItemType Directory -Path $Directory | Out-Null
        }

        $Uri = "https://www.{0}.com/ReportPDFFetch.cfm" -f ( $Server -eq 'Production' ? 'rhris' : 'rhrtest' )
        Write-Debug "Uri: $Uri"
    }

    process {

        foreach($F in $FileNo) {

            Write-Verbose "Processing FileNo: $F"

            $Body = @"
<ReportCopyRequest>
    <PartnerInfo>
        <UserID>$($Credential.UserName)</UserID>
        <Password>$($Credential.GetNetworkCredential().Password)</Password>
    </PartnerInfo>
    <Reports>
        <Report>
            <FileNo>$F</FileNo>
        </Report>
    </Reports>
</ReportCopyRequest>
"@
            Write-Debug $Body

            try {
                $Response = Invoke-WebRequest -Uri $Uri -Method Post -ContentType "application/xml" -Headers @{ Accept = "application/xml" } -Body $Body -Verbose:$false -ErrorAction Stop
                $Content = [xml]$Response.Content

                if ($Content.ReportCopyRequest.Reports.Report.PDFError) {
                    Write-Error "FileNo $F - $($Content.ReportCopyRequest.Reports.Report.PDFError)" -ErrorAction Continue
                }
                elseif ($Content.ReportCopyRequest.Reports.Report.PDF) {
                    $PdfBase64 = $Content.ReportCopyRequest.Reports.Report.PDF.'#cdata-section'
                    $PdfBytes = [System.Convert]::FromBase64String($PdfBase64)

                    $OutputPath = Join-Path $Directory "$F.pdf"
                    [System.IO.File]::WriteAllBytes($OutputPath, $PdfBytes)

                    Write-Output $OutputPath
                }
            }
            catch {
                Write-Error "Failed to retrieve report for FileNo $F - $_" -ErrorAction Continue
            }

        }

    }

}
