# Image Analysis Helper Functions for Mossy Skills
# Version: 1.0
# Date: 2026-07-28
# Purpose: Extract structured data from AI vision image analysis results

<#
.SYNOPSIS
Extract SQL error details from image analysis text

.DESCRIPTION
Parses AI vision analysis results to extract SQL error codes, messages, table names, and other error details

.PARAMETER imageAnalysis
The text analysis result from view_image tool

.EXAMPLE
$analysis = "Screenshot shows SQL error: Msg 208, Level 16, State 1, Invalid object name 'dbo.tPrice'"
$error = Extract-SQLError -imageAnalysis $analysis
# Returns: @{ErrorCode='208', Level='16', Message='Invalid object name...', Table='dbo.tPrice'}
#>
function Extract-SQLError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$imageAnalysis
    )
    
    $errorDetails = @{
        ErrorCode = $null
        Level = $null
        State = $null
        Message = $null
        Table = $null
        Column = $null
        Procedure = $null
        LineNumber = $null
        Database = $null
    }
    
    # Extract error code (Msg XXXXX)
    if ($imageAnalysis -match 'Msg\s+(\d+)') {
        $errorDetails.ErrorCode = $matches[1]
    }
    
    # Extract level
    if ($imageAnalysis -match 'Level\s+(\d+)') {
        $errorDetails.Level = $matches[1]
    }
    
    # Extract state
    if ($imageAnalysis -match 'State\s+(\d+)') {
        $errorDetails.State = $matches[1]
    }
    
    # Extract table name (dbo.TableName or schema.table pattern)
    if ($imageAnalysis -match '[\''"]?(\w+\.\w+)[\''"]?') {
        $errorDetails.Table = $matches[1]
    }
    
    # Extract column name
    if ($imageAnalysis -match 'column\s+[\''"]?(\w+)[\''"]?') {
        $errorDetails.Column = $matches[1]
    }
    
    # Extract procedure name
    if ($imageAnalysis -match 'procedure\s+[\''"]?(\w+)[\''"]?') {
        $errorDetails.Procedure = $matches[1]
    }
    
    # Extract line number
    if ($imageAnalysis -match 'line\s+(\d+)') {
        $errorDetails.LineNumber = $matches[1]
    }
    
    # Extract database name
    if ($imageAnalysis -match 'database\s+[\''"]?(\w+)[\''"]?' -and $imageAnalysis -notmatch 'database\s+object') {
        $errorDetails.Database = $matches[1]
    }
    
    # Extract full error message
    if ($imageAnalysis -match 'Msg\s+\d+.*?[\r\n](.+?)(?:[\r\n]|$)') {
        $errorDetails.Message = $matches[1].Trim()
    } elseif ($imageAnalysis -match '(?:error|exception):\s*(.+?)(?:[\r\n]|$)') {
        $errorDetails.Message = $matches[1].Trim()
    }
    
    return $errorDetails
}

<#
.SYNOPSIS
Extract Excel data from image analysis text

.DESCRIPTION
Parses AI vision analysis to extract column headers, cell values, formulas, and error indicators

.PARAMETER imageAnalysis
The text analysis result from view_image tool

.EXAMPLE
$analysis = "Excel screenshot shows Column A: CUSIP, Column B: Price. Cell A2: 03756ABS5, B2: #N/A"
$data = Extract-ExcelData -imageAnalysis $analysis
#>
function Extract-ExcelData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$imageAnalysis
    )
    
    $excelData = @{
        Headers = @()
        Cells = @()
        Formulas = @()
        Errors = @()
        HighlightedCells = @()
    }
    
    # Extract column headers (Column A: Header, Column B: Header)
    $headerMatches = [regex]::Matches($imageAnalysis, 'Column\s+([A-Z]+):\s*([^,\r\n]+)')
    foreach ($match in $headerMatches) {
        $excelData.Headers += @{
            Column = $match.Groups[1].Value
            Name = $match.Groups[2].Value.Trim()
        }
    }
    
    # Extract cell values (Cell A2: Value, B2: Value)
    $cellMatches = [regex]::Matches($imageAnalysis, '(?:Cell\s+)?([A-Z]+)(\d+):\s*([^,\r\n]+)')
    foreach ($match in $cellMatches) {
        $excelData.Cells += @{
            Column = $match.Groups[1].Value
            Row = $match.Groups[2].Value
            Value = $match.Groups[3].Value.Trim()
        }
    }
    
    # Extract formulas (starts with =)
    $formulaMatches = [regex]::Matches($imageAnalysis, '=\s*([A-Z]+\([^\)]*\)|[A-Z0-9+\-*/()]+)')
    foreach ($match in $formulaMatches) {
        $excelData.Formulas += $match.Groups[1].Value
    }
    
    # Extract Excel errors (#N/A, #VALUE!, #REF!, #DIV/0!, #NAME?, #NULL!, #NUM!)
    $errorPatterns = @('#N/A', '#VALUE!', '#REF!', '#DIV/0!', '#NAME\?', '#NULL!', '#NUM!')
    foreach ($pattern in $errorPatterns) {
        if ($imageAnalysis -match $pattern) {
            $excelData.Errors += $pattern
        }
    }
    
    # Extract highlighted cells
    if ($imageAnalysis -match 'highlighted|yellow|red|green') {
        $highlightMatches = [regex]::Matches($imageAnalysis, '([A-Z]+\d+)\s+(?:is\s+)?(?:highlighted|yellow|red|green)')
        foreach ($match in $highlightMatches) {
            $excelData.HighlightedCells += $match.Groups[1].Value
        }
    }
    
    return $excelData
}

<#
.SYNOPSIS
Extract SSIS error details from image analysis text

.DESCRIPTION
Parses AI vision analysis to extract SSIS package names, task names, error codes, and error messages

.PARAMETER imageAnalysis
The text analysis result from view_image tool

.EXAMPLE
$analysis = "SSIS error: Package 'MarkIt_Price_Import.dtsx', Task 'Data Flow Task', Error 0xC0202009"
$error = Extract-SSISError -imageAnalysis $analysis
#>
function Extract-SSISError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$imageAnalysis
    )
    
    $ssisError = @{
        PackageName = $null
        TaskName = $null
        ComponentName = $null
        ErrorCode = $null
        ErrorMessage = $null
        Timestamp = $null
        Phase = $null
    }
    
    # Extract package name (.dtsx files)
    if ($imageAnalysis -match '([\w\s]+\.dtsx)') {
        $ssisError.PackageName = $matches[1]
    } elseif ($imageAnalysis -match 'package\s+[\''"]?([^\''"]+)[\''"]?') {
        $ssisError.PackageName = $matches[1]
    }
    
    # Extract task name
    if ($imageAnalysis -match 'task\s+[\''"]?([^\''"]+)[\''"]?') {
        $ssisError.TaskName = $matches[1]
    }
    
    # Extract component name
    if ($imageAnalysis -match 'component\s+[\''"]?([^\''"]+)[\''"]?') {
        $ssisError.ComponentName = $matches[1]
    }
    
    # Extract SSIS error code (0xCXXXXXXX format)
    if ($imageAnalysis -match '(0x[0-9A-Fa-f]{8})') {
        $ssisError.ErrorCode = $matches[1]
    }
    
    # Extract error message
    if ($imageAnalysis -match 'error\s+(?:message)?:\s*(.+?)(?:[\r\n]|$)') {
        $ssisError.ErrorMessage = $matches[1].Trim()
    } elseif ($imageAnalysis -match '(data conversion failed|lookup failed|truncat(?:ed|ion))') {
        $ssisError.ErrorMessage = $matches[1]
    }
    
    # Extract timestamp
    if ($imageAnalysis -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})') {
        $ssisError.Timestamp = $matches[1]
    }
    
    # Extract execution phase
    $phases = @('Pre-Execute', 'Execute', 'Post-Execute', 'Validation', 'Preparation')
    foreach ($phase in $phases) {
        if ($imageAnalysis -match $phase) {
            $ssisError.Phase = $phase
            break
        }
    }
    
    return $ssisError
}

<#
.SYNOPSIS
Extract UI error details from image analysis text

.DESCRIPTION
Parses AI vision analysis to extract dialog types, button states, error messages, and application states

.PARAMETER imageAnalysis
The text analysis result from view_image tool

.EXAMPLE
$analysis = "Error dialog with title 'Connection Failed', message 'Unable to connect to server', OK and Cancel buttons"
$error = Extract-UIError -imageAnalysis $analysis
#>
function Extract-UIError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$imageAnalysis
    )
    
    $uiError = @{
        DialogType = $null
        DialogTitle = $null
        Message = $null
        Buttons = @()
        Icon = $null
        Application = $null
        State = $null
    }
    
    # Detect dialog type
    $dialogTypes = @('Error', 'Warning', 'Information', 'Confirmation', 'Question')
    foreach ($type in $dialogTypes) {
        if ($imageAnalysis -match "$type\s+dialog") {
            $uiError.DialogType = $type
            break
        }
    }
    
    # Extract dialog title
    if ($imageAnalysis -match 'title\s+[\''"]?([^\''"]+)[\''"]?') {
        $uiError.DialogTitle = $matches[1]
    }
    
    # Extract message
    if ($imageAnalysis -match 'message\s+[\''"]?([^\''"]+)[\''"]?') {
        $uiError.Message = $matches[1]
    }
    
    # Extract buttons
    $buttonPatterns = @('OK', 'Cancel', 'Yes', 'No', 'Retry', 'Abort', 'Ignore', 'Close', 'Apply')
    foreach ($button in $buttonPatterns) {
        if ($imageAnalysis -match "\b$button\b") {
            $uiError.Buttons += $button
        }
    }
    
    # Extract icon type
    $iconTypes = @('Error', 'Warning', 'Information', 'Question', 'Stop', 'Exclamation')
    foreach ($icon in $iconTypes) {
        if ($imageAnalysis -match "$icon\s+icon") {
            $uiError.Icon = $icon
            break
        }
    }
    
    # Extract application name
    if ($imageAnalysis -match 'application\s+[\''"]?([^\''"]+)[\''"]?' -or 
        $imageAnalysis -match '(Microsoft\s+\w+|Excel|SQL Server|Visual Studio)') {
        $uiError.Application = $matches[1]
    }
    
    # Extract state
    if ($imageAnalysis -match '(disabled|enabled|grayed out|selected|checked|unchecked)') {
        $uiError.State = $matches[1]
    }
    
    return $uiError
}

<#
.SYNOPSIS
Extract log entry details from image analysis text

.DESCRIPTION
Parses AI vision analysis to extract timestamps, log levels, logger names, messages, and stack traces

.PARAMETER imageAnalysis
The text analysis result from view_image tool

.EXAMPLE
$analysis = "2026-07-28 10:15:23 ERROR [PricingService] Failed to load prices: NullReferenceException"
$entry = Extract-LogEntry -imageAnalysis $analysis
#>
function Extract-LogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$imageAnalysis
    )
    
    $logEntry = @{
        Timestamp = $null
        Level = $null
        Logger = $null
        Message = $null
        Exception = $null
        StackTrace = @()
    }
    
    # Extract timestamp (various formats)
    $timestampPatterns = @(
        '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})',
        '(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})',
        '(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})'
    )
    foreach ($pattern in $timestampPatterns) {
        if ($imageAnalysis -match $pattern) {
            $logEntry.Timestamp = $matches[1]
            break
        }
    }
    
    # Extract log level
    $levels = @('FATAL', 'ERROR', 'WARN', 'WARNING', 'INFO', 'DEBUG', 'TRACE')
    foreach ($level in $levels) {
        if ($imageAnalysis -match "\b$level\b") {
            $logEntry.Level = $level
            break
        }
    }
    
    # Extract logger name (usually in brackets or after level)
    if ($imageAnalysis -match '\[([^\]]+)\]') {
        $logEntry.Logger = $matches[1]
    }
    
    # Extract main message
    if ($imageAnalysis -match '(?:ERROR|WARN|INFO|DEBUG)\s+(?:\[[^\]]+\])?\s*(.+?)(?:[\r\n]|$)') {
        $logEntry.Message = $matches[1].Trim()
    }
    
    # Extract exception type
    $exceptionPatterns = @(
        'NullReferenceException',
        'ArgumentException',
        'InvalidOperationException',
        'TimeoutException',
        'SqlException',
        'IOException',
        'Exception'
    )
    foreach ($exception in $exceptionPatterns) {
        if ($imageAnalysis -match $exception) {
            $logEntry.Exception = $exception
            break
        }
    }
    
    # Extract stack trace lines (at ClassName.MethodName)
    $stackMatches = [regex]::Matches($imageAnalysis, 'at\s+([\w\.]+\(.*?\))')
    foreach ($match in $stackMatches) {
        $logEntry.StackTrace += $match.Groups[1].Value
    }
    
    return $logEntry
}

<#
.SYNOPSIS
Classify screenshot type from image analysis text

.DESCRIPTION
Determines the type of screenshot (SQL error, Excel data, SSIS error, UI error, log, etc.) based on content analysis

.PARAMETER imageAnalysis
The text analysis result from view_image tool

.EXAMPLE
$analysis = "Screenshot shows SQL Server error message with table name and error code"
$type = Get-ScreenshotType -imageAnalysis $analysis
# Returns: "SQL Error"
#>
function Get-ScreenshotType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$imageAnalysis
    )
    
    # Priority-based classification (check specific patterns first)
    
    # SSIS Error (most specific)
    if ($imageAnalysis -match '\.dtsx|SSIS|0x[0-9A-Fa-f]{8}|Integration Services|data flow|pipeline') {
        return 'SSIS Error'
    }
    
    # SQL Error
    if ($imageAnalysis -match 'Msg\s+\d+|SQL\s+(?:Server\s+)?error|invalid\s+object\s+name|syntax\s+error') {
        return 'SQL Error'
    }
    
    # Excel Data
    if ($imageAnalysis -match 'Column\s+[A-Z]+|Cell\s+[A-Z]\d+|Excel|spreadsheet|#N/A|#VALUE!|formula') {
        return 'Excel Data'
    }
    
    # Log File
    if ($imageAnalysis -match 'ERROR|WARN|INFO|DEBUG|stack trace|exception|at\s+[\w\.]+\(') {
        return 'Log File'
    }
    
    # UI Error Dialog
    if ($imageAnalysis -match 'dialog|button|OK|Cancel|error\s+(?:icon|message)|window\s+title') {
        return 'UI Error Dialog'
    }
    
    # Performance/Execution Plan
    if ($imageAnalysis -match 'execution\s+plan|query\s+cost|index\s+scan|table\s+scan|CPU|I/O|wait\s+statistics') {
        return 'Execution Plan'
    }
    
    # Chart/Graph
    if ($imageAnalysis -match 'chart|graph|bar\s+chart|line\s+graph|pie\s+chart|axis|legend') {
        return 'Chart/Graph'
    }
    
    # Configuration/Settings
    if ($imageAnalysis -match 'configuration|settings|properties|checkbox|radio\s+button|dropdown') {
        return 'Configuration'
    }
    
    # Default
    return 'Unknown'
}

# Export functions
Export-ModuleMember -Function @(
    'Extract-SQLError',
    'Extract-ExcelData',
    'Extract-SSISError',
    'Extract-UIError',
    'Extract-LogEntry',
    'Get-ScreenshotType'
)
