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

fLog -pLogFile $LogFile -pMessage "$PSScriptName START"

###***** Change Source Job Names if needed *****
$GenericJobName = 'Siepe MOS Agent Bank Load'
$GenericNormalizationJobType1 = 'LegalEntity'
$GenericNormalizationJobType2 = 'Custodian Instrument'
$GenericNormalizationFeedsLabel = 'Agent Bank'
$Source = 'Siepe MOS'
$ReturnDate = ''

###***** Manually change the date if you need to re-run a Normalization or Push only *****
###$ReturnDate = [datetime]::parseexact("10/26/2023", 'MM/dd/yyyy', $null)

###***** Set the GenericImportJob variables *****
$GenericImportSQLQuery = "SELECT GenericImportJobId,SourceFolder,ArchiveLocation,FileName FROM Feeds.dbo.vGenericImportJob WHERE RefRecStatusID = 1 AND Name = '$GenericJobName' AND Source = '$Source'"
$GenericImportData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericImportSQLQuery
$GenericImportJobId = $GenericImportData.GenericImportJobId
$SourceFolder = $GenericImportData.SourceFolder
$ArchiveFolder = $GenericImportData.ArchiveLocation + '\' + $strDateNow

fLog -pLogFile $LogFile -pMessage "GenericImportJobId :: $GenericImportJobId"
fLog -pLogFile $LogFile -pMessage "SourceFolder :: $SourceFolder"
fLog -pLogFile $LogFile -pMessage "ArchiveFolder :: $ArchiveFolder"

###***** Set the GenericNormalizationJob variables *****
$GenericNormalizationSQLQuery = "SELECT GenericNormalizationJobID FROM Feeds.dbo.vGenericNormalizationJob WHERE RefRecStatusID = 1 AND GenericNormalizationJobType = '$GenericNormalizationJobType1' AND FeedsRefDataSource = '$Source' AND FeedsLabel = '$GenericNormalizationFeedsLabel'"
$GenericNormalizationData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericNormalizationSQLQuery
$GenericNormalizationJobId1 = $GenericNormalizationData.GenericNormalizationJobID

$GenericNormalizationSQLQuery = "SELECT GenericNormalizationJobID FROM Feeds.dbo.vGenericNormalizationJob WHERE RefRecStatusID = 1 AND GenericNormalizationJobType = '$GenericNormalizationJobType2' AND FeedsRefDataSource = '$Source' AND FeedsLabel = '$GenericNormalizationFeedsLabel'"
$GenericNormalizationData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericNormalizationSQLQuery
$GenericNormalizationJobId2 = $GenericNormalizationData.GenericNormalizationJobID

fLog -pLogFile $LogFile -pMessage "GenericNormalizationJobId1 :: $GenericNormalizationJobId1"
fLog -pLogFile $LogFile -pMessage "GenericNormalizationJobId2 :: $GenericNormalizationJobId2"

###****** Generic Import ******
fGenericImportJob $GenericImportJobID -pDirSourceFolder $SourceFolder -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $null -pDirArchiveFolder $ArchiveFolder ([Ref]$ReturnDate)
$RefDataSetDate = $ReturnDate

###****** Generic Normalization ******

	### Legal Entity | Agent Bank
	fGenericNormalization -pGenericNormaliztaionJobID $GenericNormalizationJobID1 -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile -pScriptName $null

	### Instrument | InstLegalEntity Relation
	fGenericNormalization -pGenericNormaliztaionJobID $GenericNormalizationJobID2 -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile -pScriptName $null

## Run Reference Data Pushes
fGenericPushReferenceData -pPushName 'LegalEntity' -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile

fGenericPushReferenceData -pPushName 'Instrument' -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile

fGenericPushReferenceData -pPushName 'InstIdentifier' -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile

fGenericPushReferenceData -pPushName 'InstLegalEntityRelation' -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile