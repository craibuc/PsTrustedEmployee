function Format-Xml {
    <#
    .SYNOPSIS
    Formats an XML string with proper indentation for readability.

    .DESCRIPTION
    Takes a raw XML string and returns a nicely formatted version with indentation.
    This function properly handles XML parsing, formatting, and resource disposal.
    The XML declaration (<?xml version="1.0"?>) is omitted by default to maintain
    compatibility with API request bodies.

    .PARAMETER Content
    The XML string to format. Must be valid XML.

    .NOTES
    The XML declaration (<?xml version="1.0"?>) is always omitted to maintain
    compatibility with API request bodies.

    .OUTPUTS
    System.String
    Returns the formatted XML string.

    .EXAMPLE
    $xml = "<root><item>value</item></root>"
    $xml | Format-Xml

    <root>
      <item>value</item>
    </root>

    Formats XML with default two-space indentation.

    .EXAMPLE
    $xml = "<root><item>value</item></root>"
    Format-Xml -Content $xml -IndentChars "`t"

    Formats XML with tab indentation.

    .NOTES
    This is a private function used internally by the PsTrustedEmployee module.
    - Properly disposes of IDisposable resources
    - Validates XML structure and reports parsing errors
    - Uses System.Xml.XmlWriter for reliable formatting
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Content
    )

    try {
        # Parse the XML to validate structure
        $xmldoc = [System.Xml.XmlDocument]::new()
        $xmldoc.LoadXml($Content)

        # Create StringWriter for output
        $sw = [System.IO.StringWriter]::new()

        try {
            # Configure XML writer settings
            $settings = [System.Xml.XmlWriterSettings]::new()
            $settings.Indent = $true
            $settings.OmitXmlDeclaration = $true

            # Create writer with settings
            $writer = [System.Xml.XmlWriter]::Create($sw, $settings)

            try {
                # Write formatted XML
                $xmldoc.WriteTo($writer)
                $writer.Flush()

                # Return formatted result
                $sw.ToString()
            }
            finally {
                # Ensure writer is disposed
                $writer.Dispose()
            }
        }
        finally {
            # Ensure StringWriter is disposed
            $sw.Dispose()
        }
    }
    catch [System.Xml.XmlException] {
        Write-Error "Invalid XML content: $($_.Exception.Message)"
        throw
    }
    catch {
        Write-Error "Failed to format XML: $($_.Exception.Message)"
        throw
    }
}
