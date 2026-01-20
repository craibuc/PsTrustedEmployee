function Get-TrustedEmployeeReportStatus {
    <#
    .SYNOPSIS
    Retrieves the status of background check reports from the Trusted Employee system.

    .DESCRIPTION
    Queries the Trusted Employee RHRIS system to retrieve the current status of one or more background check reports.
    The function sends an XML request containing file numbers and returns the status information for each report.
    This replaces the historical proprietary web interface for checking report status.

    .PARAMETER Server
    The server environment to connect to. Valid values are 'Production' or 'Testing'.
    - Production: https://www.rhris.com/ReportStatusFetch.cfm
    - Testing: https://www.rhrtest.com/ReportStatusFetch.cfm

    .PARAMETER Credential
    PSCredential object containing the UserID and Password for authenticating with the RHRIS system.

    .PARAMETER FileNo
    One or more file numbers (report IDs) to retrieve status information for. Accepts pipeline input.

    .OUTPUTS
    PSCustomObject
    Returns a custom object for each file number containing:
    - FileNo: The file number requested
    - Status: The status information if successful
    - ErrorText: Error message if the status fetch failed
    - RawXml: The raw BackgroundReports XML node if available

    .EXAMPLE
    $Credential = [pscredential]::new($Env:TRUSTED_EMPLOYEE_USERNAME, ($Env:TRUSTED_EMPLOYEE_PASSWORD | ConvertTo-SecureString -AsPlainText -Force))
    Get-TrustedEmployeeReportStatus -Server Production -Credential $Credential -FileNo '1707E7'

    Retrieves the status for a single report.

    .EXAMPLE
    $Credential = [pscredential]::new($Env:TRUSTED_EMPLOYEE_USERNAME, ($Env:TRUSTED_EMPLOYEE_PASSWORD | ConvertTo-SecureString -AsPlainText -Force))
    '1707E7', '177670' | Get-TrustedEmployeeReportStatus -Server Testing -Credential $Credential

    Retrieves status for multiple reports via pipeline.

    .EXAMPLE
    $Credential = [pscredential]::new($Env:TRUSTED_EMPLOYEE_USERNAME, ($Env:TRUSTED_EMPLOYEE_PASSWORD | ConvertTo-SecureString -AsPlainText -Force))
    $results = Get-TrustedEmployeeReportStatus -Server Production -Credential $Credential -FileNo '1707E7', '177670'
    $results | Where-Object { $_.ErrorText } | Select-Object FileNo, ErrorText

    Retrieves status for multiple reports and filters for any errors.

    .NOTES
    - The function uses HTTPS POST with content-type "application/xml"
    - Special XML characters in responses are automatically decoded by PowerShell's XML parser
    - Returns both successful status results and error information
    - HTTP 400 errors indicate authentication or protocol issues
    - HTTP 200 with ErrorText node indicates report-specific issues

    .LINK
    https://www.rhris.com
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Production', 'Testing')]
        [string]$Server,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$FileNo
    )

    begin {
        # Determine the API endpoint based on environment
        $Uri = "https://www.{0}.com/ReportStatusFetch.cfm" -f ( $Server -eq 'Production' ? 'rhris' : 'rhrtest' )
        Write-Debug "Uri: $Uri"

        # Collect all file numbers for batch processing
        $fileNumbers = [System.Collections.Generic.List[string]]::new()
    }

    process {
        # Collect file numbers from pipeline
        foreach ($F in $FileNo) {
            $fileNumbers.Add($F)
            Write-Verbose "Added FileNo: $F to request queue"
        }
    }

    end {
        # Build XML request body
        $SB = [System.Text.StringBuilder]::new()
        [void]$SB.AppendLine("<ReportStatusRequest>")
        [void]$SB.AppendLine("    <PartnerInfo>")
        [void]$SB.AppendLine("        <UserID>$([System.Security.SecurityElement]::Escape($Credential.UserName))</UserID>")
        [void]$SB.AppendLine("        <Password>$([System.Security.SecurityElement]::Escape($Credential.GetNetworkCredential().Password))</Password>")
        [void]$SB.AppendLine("    </PartnerInfo>")
        [void]$SB.AppendLine("    <Reports>")

        foreach ($F in $fileNumbers) {
            [void]$SB.AppendLine("        <Report>")
            [void]$SB.AppendLine("            <FileNo>$([System.Security.SecurityElement]::Escape($F))</FileNo>")
            [void]$SB.AppendLine("        </Report>")
        }

        [void]$SB.AppendLine("    </Reports>")
        [void]$SB.AppendLine("</ReportStatusRequest>")

        $Body = $SB.ToString()
        Write-Debug "Request Body:`n$Body"

        try {
            # Send HTTPS POST request
            $Response = Invoke-WebRequest -Uri $Uri -Method Post -ContentType "application/xml" -Body $Body -UseBasicParsing -ErrorAction Stop

            # Check for HTTP 200 OK
            if ($Response.StatusCode -eq 200) {
                Write-Verbose "Successfully received response (HTTP 200 OK)"

                # Parse XML response
                try {
                    $Content = [xml]$Response.Content
                    Write-Debug "Response XML:`n$($Response.Content)"

                    # Process each report in the response
                    foreach ($Report in $Content.ReportStatusRequest.Reports.Report) {
                        $result = [PSCustomObject]@{
                            FileNo    = $Report.FileNo
                            ErrorText = $null
                            Status    = $null
                            RawXml    = $null
                        }

                        # Check if there's an error for this report
                        if ($Report.ErrorText) {
                            $result.ErrorText = $Report.ErrorText
                            Write-Warning "FileNo $($Report.FileNo): $($Report.ErrorText)"
                        }

                        # Check if there's status information (BackgroundReports node)
                        if ($Report.BackgroundReports) {
                            $result.Status = "Available"
                            $result.RawXml = $Report.BackgroundReports
                            Write-Verbose "FileNo $($Report.FileNo): Status available"
                        }

                        # Output the result
                        Write-Output $result
                    }
                }
                catch {
                    Write-Error "Failed to parse XML response: $($_.Exception.Message)"
                    throw
                }
            }
            else {
                Write-Error "Unexpected HTTP status code: $($Response.StatusCode)"
            }
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            # Handle HTTP errors (400 Bad Request, etc.)
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorBody = $_.ErrorDetails.Message

            Write-Error @"
HTTP $statusCode Error from Trusted Employee API:
$errorBody
"@
            throw
        }
        catch {
            Write-Error "Failed to retrieve report status: $($_.Exception.Message)"
            throw
        }
    }
}
