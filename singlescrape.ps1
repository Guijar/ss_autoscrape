write-host ------------------------------------------------------
$StartTime = $(get-date)
write-host "Process start: "$StartTime
write-host ------------------------------------------------------
$ssid="guijar"
$sspassword="53462903r"
$devid="Guijar"
$devpassword="BHwOpPqhgFO"
$softname="scrapeclean"
# --------------------------------------------
$roms_orig='Y:\Descargas\no-intro\Atari - 7800'
#$roms_orig='Y:\Software\scripts\Test'
$system='Atari 2600'
# --------------------------------------------
$urlsystems="https://www.screenscraper.fr/api2/systemesListe.php?devid=$devid&devpassword=$devpassword&softname=$softname&output=xml&ssid=$ssid&sspassword=$sspassword"
$regionorder=@("es","sp","eu","wor","us","en","uk","ame","ss","jp")
$mediaslist=@("wheel","wheel-hd","video","video-normalized","box-3D","support-2D","bezel-16-9","fanart")
$unwantedroms=@("[BIOS]","(HACK)","(PROTO)","(UNL)","(BETA)","(PROMO)")
$specialromsflag=1

$romnum=0
$addedromnum=0
$updatedromnum=0
$global:skippedromnum=0
$global:webapirequests=0
$errorromnum=0
$warningromnum=0

$gameindex=-1
$gameregion=""

$xmlfolder=".\xml"


$systemsxml = "$xmlfolder\_systems.xml"

$7zpath="..\..\7z\7z.exe"

Class mediastruc {
	[string]$media_name
	[string]$dest_folder
	}

Invoke-Expression @"
Class gamestruc {
	$(echo '[string]$gameid')
	$(echo '[string]$romnumsupport')
	$(echo '[string]$romname')
	$(echo '[string]$romfolder')
	$(echo '[string]$region')
	$(echo '[string]$info')
	$(echo '[string]$info_reg')
	$($mediaslist.ForEach({"[string] `${$($_)}`n[string] `${$($_)_reg}`n"})
	)
	$(echo '[string]$md5')
	$(echo '[string]$sha1')}
"@

$client = New-Object System.Net.WebClient
$client.Encoding = [System.Text.Encoding]::UTF8

# -------------- FUNCTIONS DECLARATION ------------------

function WriteLog
{
Param ([string]$LogString)
$Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
$LogMessage = "$Stamp - $LogString"
Add-content "$LogFile" -value "$LogMessage"
}

function WriteXML
{
Param ($XMLOut)
	$XMLOut | Export-Clixml -literalpath "$xmlfolder\$system.xml" -encoding utf8
	write-host ------------------------------------------------------
	write-host "Zipping xmls..."
	$null = & $7zpath a "$zippedromxmls" "$romxmlfolder\*"
	rm -r $romxmlfolder
}


function UpdateMedia
{
Param ([System.Collections.ArrayList]$inputroms)
	
	$output=@()
	foreach ( $auxgameinfo in $inputroms )
	{
		$filepath=$auxgameinfo.romfolder+"\"+$auxgameinfo.romname
		$file=Get-ChildItem -Recurse -LiteralPath $filepath -File
		$auxxml = ReadXML $file
	
		foreach ( $mediatype in $mediaslist )
		{
			$mediatype_reg_property = $mediatype + "_reg"
			foreach ($media in $auxxml.Data.jeu.medias.media | Where type -eq $mediatype)
			{					
				$xmlmediatype=$media.type
				$xmlmediareg=$media.region
				# If stored media is not in regions list but new media is in the list
				$mr_1=($regionorder.indexof($auxgameinfo.$mediatype_reg_property) -eq -1 -and $regionorder.indexof($xmlmediareg) -gt -1)
				# Check if new media region is better than currently stored
				$mr_2=($regionorder.indexof($auxgameinfo.$mediatype_reg_property) -gt -1 -and $regionorder.indexof($xmlmediareg) -gt -1 -and $regionorder.indexof($xmlmediareg) -lt $regionorder.indexof($auxgameinfo.$mediatype_reg_property))
				# If stored media and new media are not in the regions list
				$mr_3=($auxgameinfo.$mediatype_reg_property -eq $null -and $regionorder.indexof($xmlmediareg) -eq -1)
				
				if ( ($media.type -eq "$mediatype") -and ($mr_2 -or $mr_1 -or $mr_3 -or $media.region -eq $null ))
				{				
					$auxgameinfo.$xmlmediatype=$media.innertext
					$auxgameinfo.$mediatype_reg_property=$media.region
				}										
			}
		}
		foreach ($info in $auxxml.Data.jeu.synopsis.synopsis)
		{					
			$xmlinforeg=$info.langue
			
			# If stored info is not in regions list but new info is in the list
			$mr_1=($regionorder.indexof($auxgameinfo.info_reg) -eq -1 -and $regionorder.indexof($xmlinforeg) -gt -1)
			# Check if new info region is better than currently stored
			$mr_2=($regionorder.indexof($auxgameinfo.info_reg) -gt -1 -and $regionorder.indexof($xmlinforeg) -gt -1 -and $regionorder.indexof($xmlinforeg) -lt $regionorder.indexof($auxgameinfo.info_reg))
			# If stored info and new info are not in the regions list
			$mr_3=($auxgameinfo.info_reg -eq $null -and $regionorder.indexof($xmlinforeg) -eq -1)
			
			if ( $mr_2 -or $mr_1 -or $mr_3 -or $info.langue -eq $null )
			{				
				$auxgameinfo.info=$info.innertext
				$auxgameinfo.info_reg=$info.langue
			}	
		}
		$output+=$auxgameinfo
	}
	return $output
}


function CheckRom
{
Param ([xml]$checkxml,$romfile)
	
	$fullpath=$romfile.FullName
	$romrelpath=$romfile.FullName.Substring($roms_orig.Length).trimend($romfile.name)
	$checkmd5=(Get-FileHash -LiteralPath "$fullpath" -Algorithm MD5).Hash
	$checksha1=(Get-FileHash -LiteralPath "$fullpath" -Algorithm SHA1).Hash
	
	if (!$checkxml.Data.jeu.id){$loggameid="NO-ROM-ID"}
	else{$loggameid=$checkxml.Data.jeu.id}
	
	# Discard betas, bios, demos and hacks by metadata and filename (sometimes "hack" tag has bad metadata info)
	$testflags=($checkxml.Data.jeu.rom.beta -eq $specialromsflag -or $checkxml.Data.jeu.rom.demo -eq $specialromsflag -or $checkxml.Data.jeu.rom.hack -eq $specialromsflag)
	
	if ($testflags)
	{
		return "Filename tag"
	}	
	
	foreach ($tag in $unwantedroms)
	{
		if ( $romfile.fullname.toupper().indexof("$tag") -ge 0 )
		{				
			return $tag
		}
	}
	
	## Test if file hash and scrapped rom hash match.
	if ( $checkxml.Data.jeu.rom.rommd5 -ne $checkmd5 -and $checkxml.Data.jeu.rom.romsha1 -ne $checksha1  )
	{	
		return "Hash match"
	}
	return ""
}


function ReadXML
{
	Param ($romfile)
	
	$fullpath=$romfile.FullName
	$romrelpath=$romfile.FullName.Substring($roms_orig.Length).trimend($romfile.name)
	$filemd5=(Get-FileHash -LiteralPath "$fullpath" -Algorithm MD5).Hash
	$gamexmlname = $romfile.basename+".xml"
	
	$testxml=Test-Path -LiteralPath "$romxmlfolder\$romrelpath$gamexmlname" -PathType Leaf
	
	# Get XML for current rom from Screenskraper
	if ( !$testxml )
	{
		$urlfile=[uri]::EscapeUriString($romfile.name)
		$urlrom="https://www.screenscraper.fr/api2/jeuInfos.php?devid=$devid&devpassword=$devpassword&softname=$softname&output=xml&ssid=$ssid&sspassword=$sspassword&romtype=rom&romnom=$urlfile&systemeid=$xml_systemid&md5=$filemd5"
		#write-host "API Access"
		#GetXML $urlrom		
		$err=0
		$Stoploop=$False
		[int]$Retrycount = "0"
		do
		{
			try
			{
				$global:webapirequests++
				$res=""
				$data = $client.DownloadString("$urlrom")				
			}
			catch [System.Net.WebException]
			{
				$res = $_.Exception.Response
			}
			$err=[int]$res.StatusCode
			if ( $err -eq '404' )
			{
				$global:skippedromnum++
				WriteLog "Skipping (Rom not found) ""$file"" URL=""$urlrom"""
				$null = new-item -force -path "$romxmlfolder\$relativepath$gamexmlname" -type file
				continue outer
			}
			elseif ( $err -eq '430' )
			{
				WriteLog "[WARNING] API Scrape limit exceeded."
				write-host "[WARNING] API Scrape limit exceeded. Exiting..."
				exit
			}
			elseif ( $err -eq '0' )
			{			
				$null = new-item -force -path "$romxmlfolder\$relativepath$gamexmlname" -Value $data -type file
				$Stoploop = $true
			}
			else
			{
				WriteLog "$file -> [ERROR=$err]: Server error. URL=$urlrom"
				$Retrycount = $Retrycount + 1
				#continue outer
				if ($Retrycount -gt 5)
				{
					$errorromnum+=1
					WriteLog "$file -> [ERROR=$err]: Server error, too many retrys (3)."
					continue outer
				}
			}
		}
		While ($Stoploop -eq $false)	
	}
	
	return [xml](Get-Content -LiteralPath "$romxmlfolder\$romrelpath$gamexmlname" -encoding utf8)			
}


function GetBestRegion
{
	Param ($currentreg,$incomingreg)
	#Check if rom region is better than existing one (better region for current rom and stored region )
	$gr_better=($regionorder.indexof($incomingreg) -lt $regionorder.indexof($currentreg) -and $regionorder.indexof($incomingreg) -gt -1 ) -or ( $regionorder.indexof($currentreg) -eq -1 -and $regionorder.indexof($incomingreg) -gt -1)
	#Check if exist region for current game
	$gr_current_exist=($incomingreg -and !$currentreg)
	
	if ( $gr_better -or $gr_current_exist)
	{			
		return $true
	}
	else
	{
		return $false
	}
	
}

function ButtonOnClick
{
	$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{SelectedPath = "$roms_orig"}
	[void]$FolderBrowser.ShowDialog()
	$textBox.Text = $FolderBrowser.SelectedPath
	
}

# ------------------- BEGINNING OF SCRIPT ---------------------

$testxml=Test-Path -LiteralPath $systemsxml -PathType Leaf

if ( $testxml -eq $False )
{
	$client = New-Object System.Net.WebClient
	try
	{
		$data = $client.DownloadString($urlsystems)
		Set-Content -Value $data -Path "$systemsxml"
	}
	catch [Net.WebException]
	{
		Write-Error 'The file does not exist' -ErrorAction Stop
	}
	
}

$xmldoc = [xml](Get-Content $systemsxml -encoding utf8)

# ------------------- Form begin ----------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Data Entry Form'
$form.Size = New-Object System.Drawing.Size(300,200)
$form.StartPosition = 'CenterScreen'

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(75,120)
$okButton.Size = New-Object System.Drawing.Size(75,23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(150,120)
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,20)
$label.Size = New-Object System.Drawing.Size(280,20)
$label.Text = 'Select system:'
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10,80)
$textBox.Size = New-Object System.Drawing.Size(240,20)
$textBox.Text = "$roms_orig"
$form.Controls.Add($textBox)

$pathButton = New-Object System.Windows.Forms.Button
$pathButton.Location = New-Object System.Drawing.Point(250,80)
$pathButton.Size = New-Object System.Drawing.Size(20,20)
$pathButton.Text = 'OK'
$pathButton.add_Click({ButtonOnClick})
$form.Controls.Add($pathButton)


$comboSystems = New-Object System.Windows.Forms.ComboBox
$comboSystems.Location = New-Object System.Drawing.Point(10,40)
$comboSystems.Size = New-Object System.Drawing.Size(260,20)
$comboSystems.DataBindings.DefaultDataSourceUpdateMode = 0
$comboSystems.FormattingEnabled = $true
$form.Controls.Add($comboSystems)

$systemslist=@()

foreach ($sys in $xmldoc.Data.systeme.noms.nom_launchbox)
{	
	if ($sys)
	{
		$systemslist+=$sys.split(",").trim()
	}
}

$systemslist = $systemslist | sort -uniq

$systemslist | foreach {
            $comboSystems.Items.Add($_)
            $comboSystems.SelectedIndex = 0
        } | Out-Null


$form.Topmost = $true

$form.Add_Shown({$comboSystems.Select()})
$result = $form.ShowDialog()



if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    $system = $comboSystems.Text
    $roms_orig = $textBox.Text
}
else
{
	write-host "Cancelled!"
	Exit
}

# ------------------- Form finish ----------------------

$Logfile = ".\log\$system.log"
$zippedromxmls=".\xml\zips\$system.7z"

# Test if log file exists and deletes
if (Test-Path $Logfile) {
  Remove-Item $Logfile
}



$romxmlfolder=".\xml\$system"

# Check if exists current collection xml. If exists uses it for updating from new rom set.
$testxml=Test-Path -LiteralPath "$xmlfolder\$system.xml" -PathType Leaf
if ( $testxml -eq $true )
{
	write-host "Collection xml found, using previous scrape for update."
	$gamedata = Import-Clixml -LiteralPath "$xmlfolder\$system.xml"
}
else
{
	write-host "Collection xml not found, new data to be scrapped."
	[System.Collections.ArrayList]$gamedata = @()
}

[System.Collections.ArrayList]$auxgamedata = @()


$xml_systemid=""
$xml_systemext=""

$xml_systemid=($xmldoc.Data.systeme | ? { $_.noms.nom_launchbox -ne $null -and $_.noms.nom_launchbox -eq "$system" } | Select-Object -First 1).id

if (!$xml_systemid)
{
	write-host """$system"". System not found!!!!"
	exit
}

$xml_systemext=($xmldoc.Data.systeme | ? { $_.id -eq $xml_systemid }).extensions.replace(","," .")
$xml_systemext="."+$xml_systemext
$xml_systemext=$xml_systemext.split(" ")
write-host ------------------------------------------------------
write-host "System: "$xml_systemid" - "$system
write-host "Extension: "$xml_systemext
write-host ------------------------------------------------------

pause "Check if the system and file extensions are OK and press a key. If not press Ctrl+C"

write-host ------------------------------------------------------
write-host ------------- Starting rom scrape --------------------

$testxml=Test-Path -LiteralPath "$romxmlfolder" -PathType Container
if ( $testxml -eq $False ) { $null = mkdir "$romxmlfolder" }

$testxml=Test-Path -LiteralPath $zippedromxmls -PathType Leaf

if ( $testxml )
{
	Write-host ------------------------------------------------------
	Write-host "Unzipping existing rom xml files..."
	$null = & $7zpath x -aos "$zippedromxmls" -o"$romxmlfolder"
	Write-host "Done"
	Write-host ------------------------------------------------------
}

$romlist=Get-ChildItem -Recurse -LiteralPath $roms_orig -File | Where-Object { $_.Extension -in $xml_systemext } | Sort-Object -Property FullName
$romcount=$romlist.count
Write-host "Skrapping..."
$Time = $(get-date)

:outer for ($num = 0 ; $num -le $romcount-1 ; $num++)
{
	$percentComplete = $(($($num+1) / $romlist.Count) * 100 )
    $Progress = @{
        Activity = "Current system: $system. Start at $Time"
        CurrentOperation = "Current rom: "+$romlist[$num].name
		Status = "Processing $($num+1) of $($romlist.Count) roms."
		PercentComplete = $([math]::Round($percentComplete, 2))
    }
    Write-Progress @Progress -Id 1
    
	[System.Collections.ArrayList]$procgame = @()
	$relativepath=$romlist[$num].FullName.Substring($roms_orig.Length).trimend($romlist[$num].name)
	
	$romnum+=1
	
	$romdir=$romlist[$num].Directoryname
	
	if ( $relativepath -ne "\" )
	{		
		$currentid=""
		$currentreg=""
		$rnslist=[int[]]::new(0)
		
		$romdir=$romlist[$num].Directoryname
		$auxromlist=$romlist | ? { $_.directoryname -eq "$romdir" }
		$num=$num+$auxromlist.count-1
		
		foreach ($otherrom in $auxromlist)
		{
			$bestreg=""
			$fullpath=$otherrom.FullName
			$filemd5=(Get-FileHash -LiteralPath "$fullpath" -Algorithm MD5).Hash
			$filesha1=(Get-FileHash -LiteralPath "$fullpath" -Algorithm SHA1).Hash
			
			$auxxmldoc = ReadXML $otherrom
			$testrom=CheckRom $auxxmldoc $otherrom
			
			if ( $testrom -ne "" )
			{
				#$global:skippedromnum=$global:skippedromnum+$auxromlist.count
				foreach ($out in $auxromlist)
				{
					$global:skippedromnum++
					$id=$auxxmldoc.Data.jeu.id
					$file=$out.name
					WriteLog "Skipping (romtype $testrom) $file"
				}
				continue outer
			}
			
			# Getting the game ID
			$auxgameid=$auxxmldoc.Data.jeu.id
			
			if (!$auxgameid)
			{
				write-host "error terrible!!!"
				exit
			}
			
			if ( !$currentid )
			{
				$currentid=$auxgameid
			}
			
			if ($auxgameid -ne $currentid)
			{
				#$global:skippedromnum=$global:skippedromnum+$auxromlist.count
				foreach ($out in $auxromlist)
				{
					$global:skippedromnum++
					$id=$out.gameid
					$file=$out.name
					WriteLog "Skipping (Wrong IDs): $file"
				}
				continue outer
			}			
			
			$auxromnumsupport=$auxxmldoc.Data.jeu.rom.romnumsupport
					
			# Getting the disk number for each rom
			if (!$auxromnumsupport -and !$rnslist)
			{
				WriteLog "WARNING: ""$relativepath"" -> : Check roms order, not matching romnumsupport (disk number)."
				$warningromnum+=1
				
				for ($i = 1 ; $i -le $auxromlist.count ; $i++)
				{
					$rnslist+=""
				}
				for ($i = 1 ; $i -le $auxromlist.count ; $i++)
				{
					$auxxmldocrns = ReadXML $auxromlist[$i-1]
					$rns=$auxxmldocrns.Data.jeu.rom.romnumsupport
					if ($rns)
					{
						$rnslist[$rns-1]=$true
					}
				}
				
				if ($rnslist.count -lt 0)
				{
					$auxromnumsupport=1
				}
			}
			if ( !$auxromnumsupport )
			{			
				for ($i = 1 ; $i -le $rnslist.count ; $i++)
				{
					#write-host $i $rnslist[$i-1]
					if (!($rnslist[$i-1]))
					{
						$auxromnumsupport=$i
						$rnslist[$i-1]=$true
						break
					} 						
				}	
			}
			
			#Getting the region
			foreach ($altreg in $auxxmldoc.Data.jeu.regions.region)
			{
				#write-host $regionorder.indexof($altreg) $regionorder.indexof($bestreg)
				if ( $bestreg -eq "" -or ( $regionorder.indexof($altreg) -gt -1 -and $regionorder.indexof($altreg) -lt $regionorder.indexof($bestreg)) )
				{
					$bestreg=$altreg
				}
			}
			
			
			#write-host $test " - " $currentreg " - " $bestreg
			if (GetBestRegion $currentreg $bestreg)
			{
				$currentreg=$bestreg
			}			
			$procgame += @([gamestruc]@{gameid=$auxgameid;romnumsupport=$auxromnumsupport;romname=$otherrom.name;romfolder=$otherrom.directoryname;region=$currentreg;md5=$filemd5;sha1=$filesha1})
		}
	}
	else
	{
		$bestreg=""
		$auxxmldoc = ReadXML $romlist[$num]
		$testrom=CheckRom $auxxmldoc $romlist[$num]
		
		if ( $testrom -ne "" )
		{
			$global:skippedromnum++
			$id=$auxxmldoc.gameid
			$file=$romlist[$num].name
			WriteLog "Skipping (romtype $testrom): $file"
			continue outer
		}		
		
		$auxgameid=$auxxmldoc.Data.jeu.id
		$auxromnumsupport=$auxxmldoc.Data.jeu.rom.romnumsupport
		$fullpath=$romlist[$num].fullname
		$filemd5=(Get-FileHash -LiteralPath "$fullpath" -Algorithm MD5).Hash
		$filesha1=(Get-FileHash -LiteralPath "$fullpath" -Algorithm SHA1).Hash
		
		foreach ($altreg in $auxxmldoc.Data.jeu.regions.region)
		{
			if ( $bestreg -eq "" -or ( $regionorder.indexof($altreg) -gt -1 -and $regionorder.indexof($altreg) -lt $regionorder.indexof($bestreg)) )
			{
				$bestreg=$altreg
			}
		}
		$procgame += @([gamestruc]@{gameid=$auxgameid;romnumsupport=$auxromnumsupport;romname=$romlist[$num].name;romfolder=$romlist[$num].directoryname;region=$bestreg;md5=$filemd5;sha1=$filesha1})
		
	}
	
	$id=$procgame[0].gameid
	$name=$procgame[0].romname
	$romnumsupport=$procgame[0].romnumsupport
	$procgame=@($procgame | Sort-Object -Property romnumsupport)
	
	if ($gamedata -and $gamedata.gameid.indexof($procgame[0].gameid) -gt -1)
	{
		#write-host $romnumsupport
		$romaction=($gamedata[$gamedata.gameid.indexof($procgame[0].gameid)]).region+" - "+$procgame[0].region
		
		if ( $procgame.count -eq 1 -and ($gamedata | ? { $_.gameid -eq $id -and $_.romnumsupport -eq $romnumsupport }) -eq 1 )
		{
			if (GetBestRegion ($gamedata[$gamedata.gameid.indexof($procgame[0].gameid)]).region $procgame[0].region)
			{
				$romaction="upd"+$romaction
			}
		}	
		elseif ( $procgame.count -eq 1 -and $romnumsupport -and $gamedata.gameid.indexof($procgame[0].gameid) -gt -1)
		{
			$romaction="add"+$procgame[0].region
		}
		else
		{	
			if (GetBestRegion ($gamedata[$gamedata.gameid.indexof($procgame[0].gameid)]).region $procgame[0].region)
			{
				$romaction="upd"+$romaction
			}
		}	
	}
	else
	{
		$romaction="add"+$procgame[0].region
	}
	
	$regmsg=$romaction.substring(3)
	
	if ( $romaction.substring(0,3) -eq "upd" )
	{
		#write-host "1 Upd - "$procgame[0].gameid $procgame[0].romnumsupport $procgame[0].romname 
		$updatedromnum+=$procgame.count
		$gamedata=$gamedata | ? { $_.gameid -ne $procgame[0].gameid }
		if (!$gamedata){$gamedata=@()}
		$gamedata+=UpdateMedia $procgame
		
		foreach ($out in $procgame)
		{
			$file=$out.romname
			WriteLog "Updating [$id] (region ""$regmsg""): $file"
		}
		
	}
	elseif ( $romaction.substring(0,3) -eq "add" )
	{
		# If GameID not present adds current rom/s to collection
		#write-host "2 Add - "$procgame[0].gameid $procgame[0].romnumsupport $procgame[0].romname 
		$addedromnum+=$procgame.count
		foreach ($out in $procgame)
		{
			$file=$out.romname			
			WriteLog "Adding [$id]($regmsg): $file"
		}
		if (!$gamedata){$gamedata=@()}
		$gamedata+=UpdateMedia $procgame		
	}
	else
	{
		#write-host "3 Skp - "$procgame[0].gameid $procgame[0].romnumsupport $procgame[0].romname 
		$file=$romlist[$num].name
		foreach ($out in $procgame)
		{
			$global:skippedromnum++
			$file=$out.romname
			WriteLog "Skipping [$id] (region ""$romaction""): $file"
		}		
	}
	#$gamedata
} # For end
#$gamedata.name
WriteXML $gamedata
WriteLog "Finish scrapping!"
write-host "/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\"
write-host ------------------------------------------------------
write-host "System: $system."
write-host  "Total desired roms: "$gamedata.count
write-host ------------------------------------------------------
write-host "Current script run:"
write-host "-------------------"
write-host "Scraped roms: "$romcount
write-host "Added roms: "$addedromnum
write-host "Updated roms: "$updatedromnum
write-host "Skipped roms: "$global:skippedromnum
write-host "WebAPI requests: "$global:webapirequests
write-host "Warnings: "$warningromnum
write-host "Errors: "$errorromnum
$elapsedTime = $(get-date) - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
write-host "Elapsed time: "$totalTime
write-host ------------------------------------------------------

write-host "Process finish: "$(get-date)
