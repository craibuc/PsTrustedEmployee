function ConvertTo-TrustedEmployeeApplicant {
    <#
    .SYNOPSIS
    Converts applicant data into XML format for TrustedEmployee API submission.

    .DESCRIPTION
    This private helper function transforms applicant information from PowerShell parameters into an XML <Applicant> element structure required by the TrustedEmployee background check API. The function validates input data, sanitizes sensitive information (SSN, phone), and properly encodes XML special characters to prevent injection issues.

    .PARAMETER ApplicantID
    Unique identifier for the applicant. Must be 1-50 characters.

    .PARAMETER PackageID
    Background check package type. Valid values are 1 or 2.

    .PARAMETER Copy
    Switch parameter. When specified, the applicant will receive a copy of their background check report.

    .PARAMETER FirstName
    Applicant's first name. Required. Must be 1-20 characters.

    .PARAMETER MiddleName
    Applicant's middle name. Optional. Maximum 20 characters.

    .PARAMETER LastName
    Applicant's last name. Required. Must be 1-25 characters.

    .PARAMETER BirthDate
    Applicant's date of birth as a DateTime object. Required.

    .PARAMETER SSN
    Applicant's Social Security Number. Required. Accepts formats: 123456789 or 123-45-6789. Non-numeric characters are stripped before submission.

    .PARAMETER Phone
    Applicant's phone number. Optional. Accepts formats: 1234567890 or 123-456-7890. Will be formatted as ###-###-#### in output.

    .PARAMETER Email
    Applicant's email address. Optional. Maximum 255 characters.

    .PARAMETER LicenseNumber
    Driver's license number. Optional. Maximum 30 characters.

    .PARAMETER LicenseState
    Two-letter state code for driver's license. Optional. Must be exactly 2 characters if provided.

    .PARAMETER Street
    Street address. Required. Maximum 40 characters.

    .PARAMETER Unit
    Apartment or unit number. Optional.

    .PARAMETER City
    City name. Required. Maximum 25 characters.

    .PARAMETER StateCode
    Two-letter state code for residence address. Required. Must be exactly 2 characters.

    .PARAMETER PostalCode
    ZIP code. Required. Must be exactly 5 characters.

    .PARAMETER WorkStateCode
    Two-letter state code where applicant will work. Required.

    .OUTPUTS
    System.String
    Returns an XML string containing the formatted applicant data.

    .EXAMPLE
    $params = @{
        ApplicantID = 'APP001'
        PackageID = 1
        FirstName = 'John'
        LastName = 'Doe'
        BirthDate = '1990-01-15'
        SSN = '123-45-6789'
        Phone = '555-123-4567'
        Email = 'john.doe@example.com'
        Street = '123 Main St'
        City = 'Springfield'
        StateCode = 'IL'
        PostalCode = '62701'
        WorkStateCode = 'IL'
    }
    ConvertTo-TrustedEmployeeApplicant @params

    Converts applicant data into XML format.

    .EXAMPLE
    $applicant | ConvertTo-TrustedEmployeeApplicant

    Accepts applicant data from the pipeline using property names.

    .NOTES
    This is a private function used internally by the PsTrustedEmployee module.
    - SSN is sanitized to contain only digits
    - Phone numbers are formatted as ###-###-####
    - All text fields are XML-encoded to prevent injection attacks
    - BirthDate is formatted as yyyy-MM-dd
    #>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateLength(1,50)]
        [string]$ApplicantID,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateSet(1,2)]
        [int]$PackageID,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]$Copy,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateLength(1,20)]
        [string]$FirstName,
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateLength(0,20)]
        [string]$MiddleName,
        
        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateLength(1,25)]
        [string]$LastName,
        
        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [datetime]$BirthDate,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidatePattern('^\d{3}-?\d{2}-?\d{4}$')]
        [string]$SSN,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidatePattern('^\d{10}$|^\d{3}-?\d{3}-?\d{4}$')]
        [string]$Phone,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateLength(0,255)]
        [string]$Email,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateLength(0,30)]
        [string]$LicenseNumber,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateLength(2,2)]
        [string]$LicenseState,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateLength(0,40)]
        [string]$Street,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Unit,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateLength(0,25)]
        [string]$City,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateLength(2,2)]
        [string]$StateCode,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [ValidateLength(5,5)]
        [string]$PostalCode,

        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [string]$WorkStateCode
    )

    # Helper function to XML-encode text
    $xmlEncode = { param($text) [System.Security.SecurityElement]::Escape($text) }

    # Sanitize and format phone number
    $cleanPhone = $Phone -replace "[^0-9]"
    $formattedPhone = if ($cleanPhone.Length -eq 10) {
        "$($cleanPhone.Substring(0,3))-$($cleanPhone.Substring(3,3))-$($cleanPhone.Substring(6,4))"
    } else {
        $cleanPhone
    }

    # Sanitize SSN
    $cleanSSN = $SSN -replace "[^0-9]"

    "<Applicant>
        <ApplicantID>$(& $xmlEncode $ApplicantID)</ApplicantID>
        <Package>$PackageID</Package>
        <ReportCopy>$( $Copy ? 'YES' : 'NO' )</ReportCopy>
        <FirstName>$(& $xmlEncode $FirstName)</FirstName>
        <MiddleName>$(& $xmlEncode $MiddleName)</MiddleName>
        <LastName>$(& $xmlEncode $LastName)</LastName>
        <BirthDate>$( $BirthDate.ToString('yyyy-MM-dd') )</BirthDate>
        <SSN>$cleanSSN</SSN>
        <Phone>$formattedPhone</Phone>
        <Email>$(& $xmlEncode $Email)</Email>
        <DLNumber>$(& $xmlEncode $LicenseNumber)</DLNumber>
        <DLState>$LicenseState</DLState>
        <Street>$(& $xmlEncode $Street)</Street>
        <Unit>$(& $xmlEncode $Unit)</Unit>
        <City>$(& $xmlEncode $City)</City>
        <State>$StateCode</State>
        <Zip>$PostalCode</Zip>
        <WorkState>$WorkStateCode</WorkState>
    </Applicant>"

}