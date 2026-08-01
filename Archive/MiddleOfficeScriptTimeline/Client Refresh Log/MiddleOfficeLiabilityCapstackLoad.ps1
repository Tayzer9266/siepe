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
#$ReturnDate = [datetime]::parseexact("07/31/2023", 'MM/dd/yyyy', $null)

###***** Change Source Job Names if needed *****
$GenericJobName = 'Siepe MOS LiabilityCapstack Load'
$GenericNormalizationJobType = 'Custodian Instrument'
$GenericNormalizationFeedsLabel = 'LiabilityCapstack'
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
$GenericNormalizationSQLQuery = "SELECT GenericNormalizationJobID FROM Feeds.dbo.vGenericNormalizationJob WHERE RefRecStatusID = 1 AND GenericNormalizationJobType = '$GenericNormalizationJobType' AND FeedsRefDataSource = '$Source' AND FeedsLabel = '$GenericNormalizationFeedsLabel'"
$GenericNormalizationData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericNormalizationSQLQuery
$GenericNormalizationJobId = $GenericNormalizationData.GenericNormalizationJobID

fLog -pLogFile $LogFile -pMessage "GenericNormalizationJobId :: $GenericNormalizationJobId"

####****** Generic Import ******

fGenericImportJob $GenericImportJobID -pDirSourceFolder $null -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $null -pDirArchiveFolder $null ([Ref]$ReturnDate)

####****** Generic Normalization ******

fGenericNormalization -pGenericNormaliztaionJobID $GenericNormalizationJobID -pRefDatasetDate $ReturnDate -pLogFile $LogFile -pScriptName $null

#### Run Reference Data Pushes
fGenericPushRunReferenceDataItems $LogFile
