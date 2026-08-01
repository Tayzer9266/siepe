############## Reference to configuration files ###################################
CLS

$ConfigRootFolder = $env:Powershell_ConfigRootLocation

Set-Location $ConfigRootFolder
	. .\fMasterFunctionDeclare.ps1
#################################################################################### 

###Create Log folder, if needed
if(!(Test-Path -Path $dirLogFolder )){
    New-Item -ItemType directory -Path $dirLogFolder
}

$strDateNow = get-date -format "yyyyMMddTHHmmss"
$Weekday = (get-date).DayOfWeek

$PSScriptName = $MyInvocation.MyCommand.Name.ToString()
$PSScriptName = $PSScriptName.Replace(".ps1","")
$LogFile = "$dirLogFolder\$PSScriptName."+$strDateNow+".txt"

fLog -pLogFile $LogFile -pMessage "$PSScriptName START"

$ReturnDate = ""

$GenericImportJobID = 29

$FolderSQLQuery = "SELECT SourceFolder,ArchiveLocation FROM Feeds.dbo.vGenericImportJob WHERE RefRecStatusID = 1 AND GenericImportJobID = '$GenericImportJobID' "

$Data = fExecuteSQL -pServerName $ServerName -pDatabaseName $Feeds -pQuery $FolderSQLQuery
$dirDeliveryStoreFolder = $Data.SourceFolder
$dirArchiveFolder = $Data.ArchiveLocation + "\"+$strDateNow

fLog -pLogFile $LogFile -pMessage "SourceFolder :: $dirDeliveryStoreFolder"
fLog -pLogFile $LogFile -pMessage "SourceFolder :: $dirArchiveFolder"

### We don't want to load Normalize or Push any data beyond the most recent weekday date, so we will use this section to prevent that from happening
$today = get-date -format "yyyyMMdd"
$SqlQuery = "SELECT dbo.fOffsetDate('$today','C',-1) AS MaxDate"
$MaxPositionDateResultSet = fExecuteSQL $ServerName $Core $SqlQuery $LogFile
$MaxPositionDate = $MaxPositionDateResultSet.MaxDate

if(!(Test-Path -Path $dirArchiveFolder )){
	New-Item -ItemType directory -Path $dirArchiveFolder
}

$FromDate = ""
$ToDate = ""

Set-Location $dirDeliveryStoreFolder
Write-Output "################ $(get-date -format "yyyy/MM/dd hh:mm:ss:fff") :: Changed directory to : $dirDeliveryStoreFolder  `r`n" | Out-File $LogFile -Append

####****** Split raw file into separate file per day ******
#	foreach ($strFileName in Get-ChildItem -Path $dirDeliveryStoreFolder | Where-Object {$_.Name -ilike "MOS_Aristotle Factor Extract Raw_*.csv"}) {
#		fSplitFilesDate -pSourceDirectory $dirDeliveryStoreFolder -pFileNameString $strFileName -pArchiveDirectory $dirArchiveFolder -pDateColumnName "RefDataSetDate" -pNewFileString "MOS_Aristotle Factor Extract Raw_" -pLogFile $LogFile -pDateFormat "M/d/yyyy hh:mm:ss tt"
#	}

###****** Generic Import ******
	foreach ($strFileName in Get-ChildItem -Path $dirDeliveryStoreFolder | Where-Object {$_.Name -ilike "*MOS_Aristotle Factor Extract Raw_*.csv"}) {
		$FileName = $strFileName.Name
		fGenericImportJob $GenericImportJobID -pDirSourceFolder $dirDeliveryStoreFolder -pRefDataSetDate $null -pLabel $null -pLogFile $LogFile -pFileName $FileName -pDirArchiveFolder $dirArchiveFolder ([Ref]$ReturnDate)
		$RefDataSetDate = [datetime]::parseexact($ReturnDate, 'M/d/yyyy', $null)
		Write-Output "################ $(get-date -format "yyyy/MM/dd hh:mm:ss:fff") :: RefDataSetDate: $RefDataSetDate  `r`n" | Out-File $LogFile -Append
		
		if ($FromDate -eq "" -or $RefDataSetDate -lt $FromDate) { $FromDate = $RefDataSetDate }
		if ($ToDate -eq "" -or $RefDataSetDate -gt $ToDate) { $ToDate = $RefDataSetDate }
	}
	
	if ($ToDate -gt $MaxPositionDate) { $ToDate = $MaxPositionDate }
	
###****** Generic Normalization ******
	if ($FromDate -ne "") {
		$RefDataSetDate = $FromDate

		$GenericNormalizationJobID = 19
		while ($RefDataSetDate -le $ToDate) {
			fGenericNormalization -pGenericNormaliztaionJobID $GenericNormalizationJobID -pRefDatasetDate $RefDataSetDate -pLogFile $LogFile -pScriptName $null

		    ###****** Capture InstAttributes ******
			$SqlQuery = "EXEC Custodian.pMiddleOfficeDataLoad_NormalizeInstAttributes @RefDataSetDate = '$RefDataSetDate'"
			$SqlResult = fExecuteSQL $ServerName $Feeds $SqlQuery $LogFile

			$RefDataSetDate = $RefDataSetDate.AddDays(1)
		}
    }
	
## Run Reference Data Pushes
	fGenericPushReferenceData -pPushName "LegalEntity" -pRefDatasetDate $RefDatasetDate -pLogFile $LogFile
	  
	fGenericPushReferenceData -pPushName "Instrument" -pRefDatasetDate $RefDatasetDate -pLogFile $pLogFile

	fGenericPushReferenceData -pPushName "InstIdentifier" -pRefDatasetDate $RefDatasetDate -pLogFile $pLogFile

###****** Push InstValues ******
	$SqlQuery = "EXEC GenericPushClient.pRunInstValuePush"
	$SqlResult = fExecuteSQL $ServerName $Reference $SqlQuery $LogFile 600
