############## Reference to configuration files ###################################
Clear-Host

$ConfigRootFolder = $env:Powershell_ConfigRootLocation

Set-Location $ConfigRootFolder
. .\fMasterFunctionDeclare.ps1
####################################################################################

###Create Log folder, if needed
if (!(Test-Path -Path $dirLogFolder )) {
	New-Item -ItemType directory -Path $dirLogFolder
}

$strDateNow = Get-Date -Format 'yyyyMMddTHHmmss'
$Weekday = (Get-Date).DayOfWeek

$PSScriptName = $MyInvocation.MyCommand.Name.ToString()
$PSScriptName = $PSScriptName.Replace('.ps1', '')
$LogFile = "$dirLogFolder\$PSScriptName." + $strDateNow + '.txt'
$ReturnDate = ''

###***** Change Source Job Names if needed *****
$GenericJobNameInstDebt = 'Siepe MOS InstDebt Load'
$GenericJobNameInstIssue = 'Siepe MOS InstIssue Load'
$GenericJobNameInstContractCashflow = 'Siepe MOS InstContractCashflow Load'
$GenericNormalizationJobType = 'Custodian Instrument'
$GenericNormalizationFeedsLabel = 'InstDebt-ContractCashFlow'
$Source = 'Siepe MOS'
$ReturnDate = ''

###***** Manually change the date if you need to re-run a Normalization or Push only *****
###$ReturnDate = [datetime]::parseexact("10/26/2023", 'MM/dd/yyyy', $null)


###***** Set the GenericImportJob variables *****
$GenericImportSQLQuery = "SELECT GenericImportJobId,SourceFolder,ArchiveLocation,FileName FROM Feeds.dbo.vGenericImportJob WHERE RefRecStatusID = 1 AND Name = '$GenericJobNameInstContractCashflow' AND Source = '$Source'"
$GenericImportData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericImportSQLQuery
$GenericImportJobIdInstContractCashflow = $GenericImportData.GenericImportJobId
$SourceFolder = $GenericImportData.SourceFolder
$ArchiveFolder = $GenericImportData.ArchiveLocation + '\' + $strDateNow

fLog -pLogFile $LogFile -pMessage "GenericImportJobId :: $GenericImportJobIdInstContractCashflow"
fLog -pLogFile $LogFile -pMessage "SourceFolder :: $SourceFolder"
fLog -pLogFile $LogFile -pMessage "ArchiveFolder :: $ArchiveFolder"

#####****** Generic Import InstContractCashflow ******
fGenericImportJob $GenericImportJobIdInstContractCashflow -pDirSourceFolder $null -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $null -pDirArchiveFolder $null ([Ref]$ReturnDate)

###***** Set the GenericImportJob variables *****
$GenericImportSQLQuery = "SELECT GenericImportJobId,SourceFolder,ArchiveLocation,FileName FROM Feeds.dbo.vGenericImportJob WHERE RefRecStatusID = 1 AND Name = '$GenericJobNameInstDebt' AND Source = '$Source'"
$GenericImportData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericImportSQLQuery
$GenericImportJobInstDebtId = $GenericImportData.GenericImportJobId
$SourceFolder = $GenericImportData.SourceFolder
$ArchiveFolder = $GenericImportData.ArchiveLocation + '\' + $strDateNow

fLog -pLogFile $LogFile -pMessage "GenericImportJobId :: $GenericImportJobInstDebtId"
fLog -pLogFile $LogFile -pMessage "SourceFolder :: $SourceFolder"
fLog -pLogFile $LogFile -pMessage "ArchiveFolder :: $ArchiveFolder"

#####****** Generic Import ******
fGenericImportJob $GenericImportJobInstDebtId -pDirSourceFolder $null -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $null -pDirArchiveFolder $null ([Ref]$ReturnDate)

###***** Set the GenericImportJob variables *****
$GenericImportSQLQuery = "SELECT GenericImportJobId,SourceFolder,ArchiveLocation,FileName FROM Feeds.dbo.vGenericImportJob WHERE RefRecStatusID = 1 AND Name = '$GenericJobNameInstIssue' AND Source = '$Source'"
$GenericImportData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericImportSQLQuery
$GenericImportJobInstIssueID = $GenericImportData.GenericImportJobId
$SourceFolder = $GenericImportData.SourceFolder
$ArchiveFolder = $GenericImportData.ArchiveLocation + '\' + $strDateNow

fLog -pLogFile $LogFile -pMessage "GenericImportJobId :: $GenericImportJobInstIssueID"
fLog -pLogFile $LogFile -pMessage "SourceFolder :: $SourceFolder"
fLog -pLogFile $LogFile -pMessage "ArchiveFolder :: $ArchiveFolder"

#####****** Generic Import InstIssue ******
fGenericImportJob $GenericImportJobInstIssueID -pDirSourceFolder $null -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $null -pDirArchiveFolder $null ([Ref]$ReturnDate)

###***** Set the GenericNormalizationJob variables *****
$GenericNormalizationSQLQuery = "SELECT GenericNormalizationJobID FROM Feeds.dbo.vGenericNormalizationJob WHERE RefRecStatusID = 1 AND GenericNormalizationJobType = '$GenericNormalizationJobType' AND FeedsRefDataSource = '$Source' AND FeedsLabel = '$GenericNormalizationFeedsLabel'"
$GenericNormalizationData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericNormalizationSQLQuery
$GenericNormalizationJobId = $GenericNormalizationData.GenericNormalizationJobID

fLog -pLogFile $LogFile -pMessage "GenericNormalizationJobId :: $GenericNormalizationJobId"

##****** Generic Normalization ******

fGenericNormalization -pGenericNormaliztaionJobID $GenericNormalizationJobID -pRefDatasetDate $ReturnDate -pLogFile $LogFile -pScriptName $null

## Run Reference Data Pushes
fGenericPushReferenceData -pPushName 'LegalEntity' -pRefDatasetDate $ReturnDate -pLogFile $LogFile

fGenericPushReferenceData -pPushName 'Instrument' -pRefDatasetDate $ReturnDate -pLogFile $pLogFile

fGenericPushReferenceData -pPushName 'InstIdentifier' -pRefDatasetDate $ReturnDate -pLogFile $pLogFile



fGenericPushReferenceData -pPushName 'InstDebt' -pRefDatasetDate $ReturnDate -pLogFile $pLogFile

fGenericPushReferenceData -pPushName 'InstContract' -pRefDatasetDate $ReturnDate -pLogFile $pLogFile

fGenericPushReferenceData -pPushName 'InstCashflow' -pRefDatasetDate $ReturnDate -pLogFile $pLogFile

fGenericPushReferenceData -pPushName 'InstIssue' -pRefDatasetDate $ReturnDate -pLogFile $pLogFile

fGenericPushReferenceData -pPushName 'InstContractCashflow' -pRefDatasetDate $ReturnDate -pLogFile $pLogFile