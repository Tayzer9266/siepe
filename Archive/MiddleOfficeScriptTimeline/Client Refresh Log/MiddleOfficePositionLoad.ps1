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
$GenericJobNamePosition = 'Siepe MOS Position Load'
$GenericJobNamePositionCashFlow = 'Siepe MOS PositionCashFlow Load'
$GenericNormalizationJobType = 'Custodian Position'
$GenericNormalizationFeedsLabel = 'Daily Positions'
$GenericPushName = 'Middle Office Position Load'
$Source = 'Siepe MOS'
$ReturnDate = ''

###***** Manually change the date if you need to re-run a Normalization or Push only *****
###$ReturnDate = [datetime]::parseexact("10/26/2023", 'MM/dd/yyyy', $null)

###***** Set the GenericImportJob variables *****
$GenericImportSQLQuery = "SELECT GenericImportJobId,SourceFolder,ArchiveLocation,FileName FROM Feeds.dbo.vGenericImportJob WHERE RefRecStatusID = 1 AND Name = '$GenericJobNamePosition' AND Source = '$Source'"
$GenericImportData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericImportSQLQuery
$GenericImportJobId = $GenericImportData.GenericImportJobId
$SourceFolder = $GenericImportData.SourceFolder
$ArchiveFolder = $GenericImportData.ArchiveLocation + '\' + $strDateNow

fLog -pLogFile $LogFile -pMessage "GenericImportJobId :: $GenericImportJobId"
fLog -pLogFile $LogFile -pMessage "SourceFolder :: $SourceFolder"
fLog -pLogFile $LogFile -pMessage "ArchiveFolder :: $ArchiveFolder"

### Normally, we don't want to load Normalize or Push any data beyond the most recent weekday date. But, specifically for Aristotle,
### in order to deliver data to vendors and the client (to meet daily deliverable deadlines), we need to load T positions on T.
### Checks to ensure that T data is not sent over before 4:00 pm CST on T have been setup on the MOS environment.
$today = Get-Date -Format 'yyyyMMdd'
$SqlQuery = "SELECT dbo.fOffsetDate('$today','C',0) AS MaxDate"
$MaxPositionDateResultSet = fExecuteSQL $ServerName $Core $SqlQuery $LogFile
$MaxAllowedPositionDate = $MaxPositionDateResultSet.MaxDate

fLog -pLogFile $LogFile -pMessage "MaxAllowedPositionDate :: $MaxAllowedPositionDate"

if (!(Test-Path -Path $ArchiveFolder )) {
	New-Item -ItemType directory -Path $ArchiveFolder
}

$FromDate = ''
$ToDate = ''

Set-Location $SourceFolder
Write-Output "################ $(Get-Date -Format 'yyyy/MM/dd hh:mm:ss:fff') :: Changed directory to : $SourceFolder  `r`n" | Out-File $LogFile -Append

###****** Split raw file into separate file per day ******
foreach ($strFileName in Get-ChildItem -Path $SourceFolder | Where-Object { $_.Name -ilike 'MOS_Aristotle Position Extract Raw_*.csv' }) {
	fSplitFilesDate -pSourceDirectory $SourceFolder -pFileNameString $strFileName -pArchiveDirectory $ArchiveFolder -pDateColumnName 'RefDataSetDate' -pNewFileString 'MOS_Aristotle Position Extract_' -pLogFile $LogFile -pDateFormat 'M/d/yyyy hh:mm:ss tt'
}

###****** Generic Import ******
foreach ($strFileName in Get-ChildItem -Path $SourceFolder | Where-Object { $_.Name -ilike '*MOS_Aristotle Position Extract_*.csv' }) {
	$FileName = $strFileName.Name
	fGenericImportJob $GenericImportJobID -pDirSourceFolder $SourceFolder -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $FileName -pDirArchiveFolder $ArchiveFolder ([Ref]$ReturnDate)
	$RefDataSetDate = [datetime]::parseexact($ReturnDate, 'M/d/yyyy', $null)
	Write-Output "################ $(Get-Date -Format 'yyyy/MM/dd hh:mm:ss:fff') :: RefDataSetDate: $RefDataSetDate  `r`n" | Out-File $LogFile -Append

	if ($FromDate -eq '' -or $RefDataSetDate -lt $FromDate) { $FromDate = $RefDataSetDate }
	if ($ToDate -eq '' -or $RefDataSetDate -gt $ToDate) { $ToDate = $RefDataSetDate }
}

###***** Set the GenericImportJob variables *****
$GenericImportSQLQuery = "SELECT GenericImportJobId,SourceFolder,ArchiveLocation,FileName FROM Feeds.dbo.vGenericImportJob WHERE RefRecStatusID = 1 AND Name = '$GenericJobNamePositionCashFlow' AND Source = '$Source'"
$GenericImportData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericImportSQLQuery
$GenericImportJobId = $GenericImportData.GenericImportJobId
$SourceFolder = $GenericImportData.SourceFolder
$ArchiveFolder = $GenericImportData.ArchiveLocation + '\' + $strDateNow

fLog -pLogFile $LogFile -pMessage "GenericImportJobId :: $GenericImportJobId"
fLog -pLogFile $LogFile -pMessage "SourceFolder :: $SourceFolder"
fLog -pLogFile $LogFile -pMessage "ArchiveFolder :: $ArchiveFolder"

if (!(Test-Path -Path $ArchiveFolder )) {
	New-Item -ItemType directory -Path $ArchiveFolder
}

###***** Set the GenericNormalizationJob variables *****
$GenericNormalizationSQLQuery = "SELECT GenericNormalizationJobID FROM Feeds.dbo.vGenericNormalizationJob WHERE RefRecStatusID = 1 AND GenericNormalizationJobType = '$GenericNormalizationJobType' AND FeedsRefDataSource = '$Source' AND FeedsLabel = '$GenericNormalizationFeedsLabel'"
$GenericNormalizationData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericNormalizationSQLQuery
$GenericNormalizationJobId = $GenericNormalizationData.GenericNormalizationJobID

fLog -pLogFile $LogFile -pMessage "GenericNormalizationJobId :: $GenericNormalizationJobId"

###***** Set the GenericPushJob variables *****
$GenericPushSQLQuery = "SELECT GenericPushJobID FROM feeds.dbo.vGenericPushJob WHERE Name = '$GenericPushName' AND RefRecStatusID = 1"
$GenericPushData = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $GenericPushSQLQuery
$GenericPushJobID = $GenericPushData.GenericPushJobID

fLog -pLogFile $LogFile -pMessage "GenericPushJobID :: $GenericPushJobID"

Set-Location $SourceFolder
Write-Output "################ $(Get-Date -Format 'yyyy/MM/dd hh:mm:ss:fff') :: Changed directory to : $SourceFolder  `r`n" | Out-File $LogFile -Append

###****** Split raw file into separate file per day ******
foreach ($strFileName in Get-ChildItem -Path $SourceFolder | Where-Object { $_.Name -ilike 'MOS_Aristotle PositionCashflow Extract Raw_*.csv' }) {
	fSplitFilesDate -pSourceDirectory $SourceFolder -pFileNameString $strFileName -pArchiveDirectory $ArchiveFolder -pDateColumnName 'RefDataSetDate' -pNewFileString 'MOS_Aristotle PositionCashflow Extract_' -pLogFile $LogFile -pDateFormat 'M/d/yyyy'
}

###****** Generic Import ******
foreach ($strFileName in Get-ChildItem -Path $SourceFolder | Where-Object { $_.Name -ilike '*MOS_Aristotle PositionCashflow Extract_*.csv' }) {
	$FileName = $strFileName.Name
	fGenericImportJob $GenericImportJobID -pDirSourceFolder $SourceFolder -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $FileName -pDirArchiveFolder $ArchiveFolder ([Ref]$ReturnDate)
	$RefDataSetDate = [datetime]::parseexact($ReturnDate, 'M/d/yyyy', $null)
	Write-Output "################ $(Get-Date -Format 'yyyy/MM/dd hh:mm:ss:fff') :: RefDataSetDate: $RefDataSetDate  `r`n" | Out-File $LogFile -Append

	if ($FromDate -eq '' -or $RefDataSetDate -lt $FromDate) { $FromDate = $RefDataSetDate }
	if ($ToDate -eq '' -or $RefDataSetDate -gt $ToDate) { $ToDate = $RefDataSetDate }
}

if ($ToDate -gt $MaxAllowedPositionDate) { $ToDate = $MaxAllowedPositionDate }

if ($FromDate -is [datetime] -and $ToDate -is [datetime]) {
	###****** Generic Normalization ******
	$RefDataSetDate = $FromDate

	while ($RefDataSetDate -le $ToDate) {
		fGenericNormalization -pGenericNormaliztaionJobID $GenericNormalizationJobID -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile -pScriptName $null

		###****** Capture InstAttributes ******
		$SqlQuery = "EXEC Custodian.pMiddleOfficeDataLoad_NormalizeInstAttributes @RefDataSetDate = '$RefDataSetDate'"
		$SqlResult = fExecuteSQL $ServerName $Feeds $SqlQuery $LogFile

		$RefDataSetDate = $RefDataSetDate.AddDays(1)
	}

	## Run Reference Data Pushes
	fGenericPushReferenceData -pPushName 'LegalEntity' -pRefDatasetDate $RefDatasetDate -pLogFile $LogFile

	fGenericPushReferenceData -pPushName 'Instrument' -pRefDatasetDate $RefDatasetDate -pLogFile $pLogFile

	fGenericPushReferenceData -pPushName 'InstIdentifier' -pRefDatasetDate $RefDatasetDate -pLogFile $pLogFile

	fGenericPushReferenceData -pPushName 'Portfolio' -pRefDatasetDate $RefDatasetDate -pLogFile $pLogFile


	### Run the Position Push for the date range identified
	$RefDataSetDate = $FromDate

	### Run Push for each date
	while ($RefDataSetDate -le $ToDate) {
		fGenericPush $GenericPushJobID -pRefDatasetDate $RefDatasetDate -pLogFile $LogFile -pScriptName $PSScriptName

		$RefDataSetDate = $RefDataSetDate.AddDays(1)
	}

	###***** Get the max loaded position date *****###
	$SqlQuery = "SELECT MAX(RefDataSetDate) AS MaxLoadedPositionDate FROM Core.dbo.vRefDataSetActive WHERE Label = 'tPosition' AND IsActive = 1"
	$MaxLoadedPositionDateResultSet = fExecuteSQL $ServerName $Core $SqlQuery $LogFile
	$MaxLoadedPositionDate = $MaxLoadedPositionDateResultSet.MaxLoadedPositionDate

	### Run PortalCalcs for entire date range
	[string]$summaryStatus = ''
	Write-Output "################ $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss:fff') :: Running PortalCalcs for $FromDate to $MaxLoadedPositionDate...  `r`n" | Out-File $LogFile -Append
	Run-PortalCalc -HostName 'http://localhost:5050' -StartDate $FromDate -EndDate $MaxLoadedPositionDate -LogFile $LogFile -PortalCalcStatus ([ref]$summaryStatus)
	Write-Output "################ $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss:fff') :: PortalCalcs complete  `r`n" | Out-File $LogFile -Append

}
