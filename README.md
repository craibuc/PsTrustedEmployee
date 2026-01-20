# PsTrustedEmployee

## Functions

### Get-TrustedEmployeeReport

pwsh```
$Credential = [pscredential]::new($Env:TRUSTED_EMPLOYEE_USERNAME,($Env:TRUSTED_EMPLOYEE_PASSWORD| ConvertTo-SecureString -AsPlainText -Force))

'ABCDEF','123456' | Get-TrustedEmployeeReport -Server Production -Credential $Credential -Directory '~/Desktop/Trusted Employee'
```