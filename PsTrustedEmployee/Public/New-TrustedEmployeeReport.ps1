function New-TrustedEmployeeReport {
    <#
    .SYNOPSIS
    Submits a new background check report request to the Trusted Employee system.

    .DESCRIPTION
    Creates and submits a background check screening request to the Trusted Employee RHRIS system.
    The function accepts applicant information via the pipeline, builds the required XML request,
    and submits it to the BatchScreensXML API endpoint. Multiple applicants can be processed in
    a single batch request.

    .PARAMETER Server
    The server environment to connect to. Valid values are 'Production' or 'Testing'.
    - Production: https://www.rhris.com/BatchScreensXML.cfm
    - Testing: https://www.rhrtest.com/BatchScreensXML.cfm

    .PARAMETER Credential
    PSCredential object containing the UserID and Password for authenticating with the RHRIS system.

    .PARAMETER Account
    The 6-character account number for billing and tracking purposes.

    .PARAMETER Package
    Background check package type. Valid values:
    - 1: New hire package
    - 2: New hire + DMV (includes driving record check)

    .PARAMETER WebHookUri
    URL where Trusted Employee will POST status updates and completed reports.
    The CredentialType is set to 'NONE' by default.

    .PARAMETER Applicant
    Applicant object(s) containing the required information for background check processing.
    Accepts pipeline input. Each applicant must include:
    - ApplicantID, FirstName, LastName, BirthDate, SSN, Street, City, StateCode, PostalCode, WorkStateCode
    Optional fields: MiddleName, Phone, Email, LicenseNumber, LicenseState, Unit, Copy

    .OUTPUTS
    System.String
    Returns the formatted XML request body that was sent to the API.

    .EXAMPLE
    $Credential = [pscredential]::new($ENV:TRUSTED_EMPLOYEE_USERNAME, ($ENV:TRUSTED_EMPLOYEE_PASSWORD | ConvertTo-SecureString -AsPlainText -Force))

    $applicant = [pscustomobject]@{
        ApplicantId = New-Guid | Select-Object -ExpandProperty Guid
        PackageId = 1
        Copy = $true
        FirstName = 'JONATHAN'
        MiddleName = 'JAY'
        LastName = 'DOE'
        BirthDate = '1990-01-15'
        SSN = '123-45-6789'
        Phone = '(612) 555-1212'
        Email = 'jonathan.doe@test.com'
        Street = '123 MAIN ST'
        Unit = '101'
        City = 'Hopkins'
        StateCode = 'MN'
        PostalCode = '55343'
        LicenseState = 'MN'
        LicenseNumber = 'D12345678'
        WorkStateCode = 'MN'
    }

    $applicant | New-TrustedEmployeeReport -Server Testing -Credential $Credential -Account '41262S' -Package 1 -WebHookUri 'https://www.example.com/webhook'

    Submits a single applicant for background check processing.

    .EXAMPLE
    $Credential = [pscredential]::new($ENV:TRUSTED_EMPLOYEE_USERNAME, ($ENV:TRUSTED_EMPLOYEE_PASSWORD | ConvertTo-SecureString -AsPlainText -Force))

    $applicants = Import-Csv applicants.csv
    $applicants | New-TrustedEmployeeReport -Server Production -Credential $Credential -Account '41262S' -Package 2 -WebHookUri 'https://api.company.com/te-webhook'

    Submits multiple applicants from a CSV file for batch processing.

    .NOTES
    - All applicant data is validated and XML-encoded to prevent injection attacks
    - SSN and phone numbers are automatically sanitized and formatted
    - The function returns the formatted XML for debugging purposes
    - Status updates will be POSTed to the WebHookUri when reports are completed

    .LINK
    https://www.rhris.com
    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Production','Testing')]
        [string]$Server,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [ValidateLength(6,6)]
        [string]$Account,

        [Parameter(Mandatory)]
        [ValidateSet(1,2)]
        [int]$Package,

        [Parameter(Mandatory)]
        [uri]$WebHookUri,

        [Parameter(ValueFromPipeline,Mandatory)]
        [object]$Applicant
    )
    
    begin {
        # Determine the API endpoint based on environment
        $Uri = "https://www.{0}.com/BatchScreensXML.cfm" -f ( $Server -eq 'Production' ? 'rhris' : 'rhrtest' )
        Write-Debug "Uri: $Uri"

        # Build XML request
        $SB = [System.Text.StringBuilder]::new()
        [void]$SB.AppendLine("<ScreenRequest>")

        # Add authentication info with XML encoding
        [void]$SB.AppendLine("    <PartnerInfo>")
        [void]$SB.AppendLine("        <UserID>$([System.Security.SecurityElement]::Escape($Credential.UserName))</UserID>")
        [void]$SB.AppendLine("        <Password>$([System.Security.SecurityElement]::Escape($Credential.GetNetworkCredential().Password))</Password>")
        [void]$SB.AppendLine("    </PartnerInfo>")

        # Add account and webhook info with XML encoding
        [void]$SB.AppendLine("    <Account>")
        [void]$SB.AppendLine("        <AcctNbr>$([System.Security.SecurityElement]::Escape($Account))</AcctNbr>")
        if ($WebHookUri) {
            [void]$SB.AppendLine("        <PostBackURL CredentialType='NONE'>$([System.Security.SecurityElement]::Escape($WebHookUri.AbsoluteUri))</PostBackURL>")
        }
    }
    
    process {
        # Process each applicant and add to XML request
        foreach ($A in $Applicant) {
            Write-Verbose "Processing applicant: $($A.FirstName) $($A.LastName)"

            # Convert applicant data to XML and append
            $applicantXml = $A | ConvertTo-TrustedEmployeeApplicant
            [void]$SB.AppendLine($applicantXml)
        }
    }
    
    end {
        # Close XML structure
        [void]$SB.AppendLine("    </Account>")
        [void]$SB.AppendLine("</ScreenRequest>")

        # Format the XML for readability
        try {
            $Xml = Format-Xml -Content $SB.ToString()
            Write-Debug "Formatted XML Request:`n$Xml"
        }
        catch {
            Write-Error "Failed to format XML request: $($_.Exception.Message)"
            throw
        }

        # Submit the request to the API
        try {
            Write-Verbose "Submitting request to $Uri"

            $Response = Invoke-WebRequest -Uri $Uri -Method Post -ContentType "application/xml" -Body $Xml -UseBasicParsing -ErrorAction Stop

            # Check for HTTP 200 OK
            if ($Response.StatusCode -eq 200) {
                Write-Verbose "Successfully submitted request (HTTP 200 OK)"

                # Parse XML response
                try {
                    $Content = [xml]$Response.Content
                    Write-Debug "Response XML:`n$($Response.Content)"

                    # Return the response for further processing
                    Write-Output $Content
                }
                catch {
                    Write-Error "Failed to parse XML response: $($_.Exception.Message)"
                    Write-Debug "Raw response: $($Response.Content)"
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
            Write-Error "Failed to submit report request: $($_.Exception.Message)"
            throw
        }
    }

}