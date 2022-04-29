# -----------------------------------------------
$bezelini+="[General]`r`n"
$bezelini+="Bezel Screen Top Left X Coordinate=250`r`n"
$bezelini+="Bezel Screen Top Left Y Coordinate=13`r`n"
$bezelini+="Bezel Screen Bottom Right X Coordinate=1670`r`n"
$bezelini+="Bezel Screen Bottom Right Y Coordinate=1070`r`n"
# -----------------------------------------------
$xmlfolder="Y:\Software\scripts\scrapeclean\xml"
$RLpath="Y:\Software\RocketLauncher"
$regionorder=@("es","sp","eu","wor","en","us","ame","ss","jp")
$romdestfolder="Y:\roms"
$mediapath="Y:\media"
$7zpath="..\..\7z\7z.exe"
$AMpath="Y:\Software\Attract Mode"

$RLexe=$RLpath+"\RocketLauncher.exe"
$AMexe=$AMpath+"\attract.exe"
$AMcfgpath=$AMpath+"\attract.cfg"
$RLdefaultmodule="RetroArch"
$systemsxml = "$xmlfolder\_systems.xml"
$RLRAmodule=$RLpath+"\Modules"

$romnum=0
$global:downloadedmedia=0
$global:totalmedia=0
$global:notfoundmedia=0
#$webapirequests=0

$StartTime = $(get-date)

Class mediastruc
{
	[string]$tag
	[string]$extension
	[string]$destpath
	[string]$AMart
}

$mediadata += @([mediastruc]@{tag="video";extension="mp4";destpath="video";AMart="snap"})
$mediadata += @([mediastruc]@{tag="wheel-hd";extension="png";destpath="Logos";AMart="wheel"})
$mediadata += @([mediastruc]@{tag="box-3D";extension="png";destpath="box-3D";AMart="boxart"})
$mediadata += @([mediastruc]@{tag="support-2D";extension="png";destpath="support-2D";AMart="cartart"})
$mediadata += @([mediastruc]@{tag="bezel-16-9";extension="png";destpath="Bezels";AMart="bezel"})
$mediadata += @([mediastruc]@{tag="fanart";extension="png";destpath="fanart";AMart="fanart"})

foreach ( $media in $mediadata )
{
	$path=$mediapath+"\"+$media.destpath+"\"+$system
	$testfolder=Test-Path -LiteralPath "$path" -PathType Container
	if ( $testfolder -eq $False ) { $null = & mkdir "$path" }
}

function WriteLog
{
	Param ([string]$LogString)
	$Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
	$LogMessage = "$Stamp - $LogString"
	Add-content "$LogFile" -value "$LogMessage" -encoding utf8
}

function DownloadMedia
{
	Param ([string]$url,[string]$path)
	$global:totalmedia++
	if ( $url -eq "" -or $url -eq $null )
	{
		$LogMessage = "[$path]"
		$global:notfoundmedia++
		WriteLog "$LogMessage"
		return
	}

	$testdest=$(Test-Path -LiteralPath "$path" -PathType Leaf)
	
	if ( !$testdest )
	{		
		$null=New-Item -ItemType Directory -Force -Path $("$path" | Split-Path )

		#write-host $("Downloading new media: "+"$path")
		$wc = New-Object System.Net.WebClient
		try
		{
			$global:downloadedmedia++
			$wc.DownloadFile("$url","$path")
		}
		catch [Net.WebException]
		{
			WriteLog "Server error. Closing."
			Write-Error 'Server error!' -ErrorAction Stop
		}
	}
}

# ------------------- Form begin ----------------------

function LoadcomboRL
{
	$selected = $comboRLmodule.text + ".ahk"
	$ahkfile = ($modulesfiles | Where-Object { $_.name -eq "$selected" }).fullname
	$file=get-content "$ahkfile" -encoding utf8 | Select-String "MSystem"
	$r = [regex] "\[([^\[]*)\]"
	$match = $r.match("$file")
	$RLsystems = $match.groups[1].value.split(",").replace("""","")
	$comboRL.Items.Clear()
	$RLsystems | sort -uniq | foreach {
				$comboRL.Items.Add($_)
			} | Out-Null
	$comboRL.SelectedIndex = 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Data Entry Form'
$form.Size = New-Object System.Drawing.Size(300,300)
$form.StartPosition = 'CenterScreen'

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(50,200)
$okButton.Size = New-Object System.Drawing.Size(75,23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(150,200)
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$labelSystem = New-Object System.Windows.Forms.Label
$labelSystem.Location = New-Object System.Drawing.Point(10,20)
$labelSystem.Size = New-Object System.Drawing.Size(280,20)
$labelSystem.Text = 'Select system:'
$form.Controls.Add($labelSystem)

$comboSystems = New-Object System.Windows.Forms.ComboBox
$comboSystems.Location = New-Object System.Drawing.Point(10,40)
$comboSystems.Size = New-Object System.Drawing.Size(260,20)
$comboSystems.DataBindings.DefaultDataSourceUpdateMode = 0
$comboSystems.FormattingEnabled = $true
$comboSystems.DropDownStyle = 2
$form.Controls.Add($comboSystems)

$systemslist=@()

$systemsxmls=(Get-ChildItem -LiteralPath "$xmlfolder" -File | Where-Object { $_.Extension -eq ".xml" -and $_.name.substring(0,1) -ne "_" } | Sort-Object -Property FullName).name

foreach ($sys in $systemsxmls)
{	
	if ($sys)
	{
		$systemslist+=[System.Io.Path]::GetFileNameWithoutExtension("$sys")
	}
}

$systemslist | foreach {
            $comboSystems.Items.Add($_)            
        } | Out-Null
$comboSystems.SelectedIndex = 0

$labelRLmodule = New-Object System.Windows.Forms.Label
$labelRLmodule.Location = New-Object System.Drawing.Point(10,70)
$labelRLmodule.Size = New-Object System.Drawing.Size(280,20)
$labelRLmodule.Text = 'Select RocketLauncher module:'
$form.Controls.Add($labelRLmodule)

$comboRLmodule = New-Object System.Windows.Forms.ComboBox
$comboRLmodule.Location = New-Object System.Drawing.Point(10,90)
$comboRLmodule.Size = New-Object System.Drawing.Size(260,20)
$comboRLmodule.DataBindings.DefaultDataSourceUpdateMode = 0
$comboRLmodule.FormattingEnabled = $true
$comboRLmodule.DropDownStyle = 2
$form.Controls.Add($comboRLmodule)

$moduleslist=@()

$modulesfiles=Get-ChildItem -LiteralPath "$RLRAmodule" -File -Recurse | Where-Object { $_.Extension -eq ".ahk" } | Sort-Object -Property FullName

foreach ($mod in $modulesfiles.name)
{	
	if ($mod)
	{
		$moduleslist+=[System.Io.Path]::GetFileNameWithoutExtension("$mod")
	}
}

$moduleslist | foreach {
            $comboRLmodule.Items.Add($_)
        } | Out-Null
		
$comboRLmodule.SelectedIndex = $comboRLmodule.FindStringExact("$RLdefaultmodule")

$comboRLmodule.add_SelectedValueChanged({LoadcomboRL})

$labelRL = New-Object System.Windows.Forms.Label
$labelRL.Location = New-Object System.Drawing.Point(10,120)
$labelRL.Size = New-Object System.Drawing.Size(280,20)
$labelRL.Text = 'Select RocketLauncher system:'
$form.Controls.Add($labelRL)

$comboRL = New-Object System.Windows.Forms.ComboBox
$comboRL.Location = New-Object System.Drawing.Point(10,140)
$comboRL.Size = New-Object System.Drawing.Size(260,20)
$comboRL.DataBindings.DefaultDataSourceUpdateMode = 0
$comboRL.FormattingEnabled = $true
$comboRL.DropDownStyle = 2
$form.Controls.Add($comboRL)

LoadcomboRL

$form.Topmost = $true
$form.Add_Shown({$comboSystems.Select()})
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    $system = $comboSystems.Text
    $RLsystem = $comboRL.Text
}
else
{
	write-host "Cancelled!"
	Exit
}

$RLmodule = $comboRLmodule.Text

# ------------------- Form finish ----------------------

$romdest="$romdestfolder\$RLsystem"
$AMemucfg=$AMpath+"\emulators\"+$RLsystem+".cfg"
$AMromlist=$AMpath+"\romlists\"+$RLsystem+".txt"
$Logfile = ".\log\"+$system+" (parser).log"
$RLemuini=$RLpath+"\Settings\"+$RLsystem+"\Emulators.ini"

if (Test-Path $Logfile) {Remove-Item $Logfile}

$testxml=Test-Path -LiteralPath "$xmlfolder\$system.xml" -PathType Leaf
if ( $testxml -eq $true )
{
	write-host "Collection xml found, using ""$system"" input file."
	$gamedata = Import-Clixml -LiteralPath "$xmlfolder\$system.xml"
}
else
{
	write-host "XML not found!! Exiting..."
	exit
}

$gameidlist=$gamedata.gameid | sort -uniq

# Initialize the romlist file
$romslisttext="#Name;Title;Emulator;CloneOf;Year;Manufacturer;Category;Players;Rotation;Control;Status;DisplayCount;DisplayType;AltRomname;AltTitle;Extra;Buttons;Series;Language;Region;Rating"
Set-content "$AMromlist" -value "$romslisttext" -encoding utf8

#Get system media
$systems = [xml](Get-Content $systemsxml -encoding utf8)
$currentsys=($systems.Data.systeme | ? { $_.noms.nom_launchbox -ne $null -and $_.noms.nom_launchbox -eq "$system" } | Select-Object -First 1)

#wheel
$syswheel=($currentsys.medias.media | ? { $_.type.indexof("wheel") -gt -1 } | Select-Object -First 1).innertext
$path=$("$AMpath"+"\layouts\"+"$system"+"\wheel.png")
if ((Get-FileHash -LiteralPath "$path" -Algorithm SHA1).Hash -eq "F7A5F7A29189A48A1C09179FE50E48E7FD254D74" )
{mv "$path" $("$path"+"_bkp")}
DownloadMedia "$syswheel" "$path"
$testpath=Test-Path -LiteralPath "$path" -PathType Leaf
if ( !$testpath )
{
	mv $("$path"+"_bkp") "$path"
}
elseif ($(Test-Path -LiteralPath $("$path"+"_bkp") -PathType Leaf))
{
	rm $("$path"+"_bkp")
}

#bezel
$bezels=$currentsys.medias.media | ? { $_.type.indexof("bezel-16-9") -gt -1 }
$bestreg=""
foreach ($bezreg in $bezels.region)
{
	if ( $bestreg -eq "" -or ( $regionorder.indexof($bezreg) -gt -1 -and $regionorder.indexof($bezreg) -lt $regionorder.indexof($bestreg)) )
	{
		$bestreg=$bezreg
	}
}
$sysbezel=($currentsys.medias.media | ? { $_.type.indexof("bezel-16-9") -gt -1 -and $_.region -eq $bestreg }).innertext
$path=$($mediapath+"\Bezels\"+$RLsystem+"\_Default\bezel_16_9.png")
DownloadMedia "$sysbezel" "$path"
$testpath=Test-Path -LiteralPath "$path" -PathType Leaf
if ( $testpath )
{
	$bezelinipath=$("$path" | Split-Path)+"\"+$([System.Io.Path]::GetFileNameWithoutExtension("$path").tostring())+".ini"
	Set-content "$bezelinipath" -value "$bezelini" -encoding utf8
}

$num=0
$Time = $(get-date)

write-host ------------------------------------------------------
write-host "Source system xml: "$system
write-host "Destination RocketLauncher system: "$RLsystem
write-host ------------------------------------------------------

write-host "Starting rom copying and media scrape..."

foreach ($gameid in $gameidlist)
{
	$gameroms=$gamedata | Where-Object { $_.gameid -eq "$gameid" }
	#$gameroms[0].romname
	
	$percentComplete = $(($($num+1) / $gameidlist.Count) * 100 )
    $Progress = @{
        Activity = "Current system: $system. Start at $Time"
        CurrentOperation = "Current game: "+"$gameid"+" - "+$gameroms[0].romname
		Status = "Processing $($num+1) of $($gameidlist.Count) games."
		PercentComplete = $([math]::Round($percentComplete, 2))
    }
    Write-Progress @Progress -Id 1
	$num++
		
	if ($gameroms.count -gt 1)
	{
		$relativepath=(get-item $gameroms[0].romfolder).fullname.substring((get-item $gameroms[0].romfolder).parent.fullname.length)
	}
	else {$relativepath=""}
	
	
	#Start of copying roms
	$gamepath=$romdest+$relativepath
	
	$testfolder=Test-Path -LiteralPath "$gamepath" -PathType Container
	if ( $testfolder -eq $False ) { $null = & mkdir "$gamepath" }
	
	if ( Test-Path -LiteralPath "$romdest$relativepath.m3u" -PathType Leaf )
	{
		rm "$romdest$relativepath.m3u"
	}
	
	foreach ($rom in $gameroms)
	{			
		$romname=[System.Io.Path]::GetFileNameWithoutExtension("$($rom.romname)").tostring()	
		$testdest=Test-Path -LiteralPath "$gamepath\$romname.7z" -PathType Leaf
		
		if ( !$testdest )
		{			
			$null = & $7zpath a "$gamepath\$romname.7z" "$($rom.romfolder+"\"+$rom.romname)"
		}
		
		#If the game has more than 1 rom it creates m3u files
		if ($gameroms.count -gt 1)
		{
			$cues = ".$relativepath\$romname.7z"
			Add-Content -Value $cues "$romdest$relativepath.m3u" -encoding utf8
			$romname=("$relativepath").substring(1)
		}
		else
		{
			$aux=$gameroms[0].romname
			$romname=[System.Io.Path]::GetFileNameWithoutExtension("$aux").tostring()
		}
	}
	
	#Generating romlist entry
	$listName=$romname
	$listTitle=$romname
	$listEmulator="$RLsystem"
	$romslisttext="$listName"+";"+"$listTitle"+";"+"$listEmulator"+";"+"$listCloneOf"+";"+"$listYear"+";"+"$listManufacturer"+";"+"$listCategory"+";"+"$listPlayers"+";"+"$listRotation"+";"+"$listControl"+";"+"$listStatus"+";"+"$listDisplayCount"+";"+"$listDisplayType"+";"+"$listAltRomname"+";"+"$listAltTitle"+";"+"$listExtra"+";"+"$listButtons"+";"+"$listSeries"+";"+"$listLanguage"+";"+"$listRegion"+";"+"$listRating"
	Add-Content "$AMromlist" -value "$romslisttext" -encoding utf8
	
	$wheel_hd_regorder=$regionorder.indexof($gameroms[0]."wheel-hd_reg")
	$wheel_regorder=$regionorder.indexof($gameroms[0]."wheel_reg")
	foreach ( $media in $mediadata )
	{			
		$url=$gameroms[0].$($media."tag")
		$dest=$mediapath+"\"+$media.destpath+"\"+$RLsystem+"\"+$romname+"."+$media.extension
		
		if ( $media.tag -eq "wheel-hd" -or $media.tag -eq "wheel" )
		{
			if ($wheel_hd_regorder -ge 0 -and $wheel_hd_regorder -le $wheel_regorder)
			{				
				$url=$gameroms[0]."wheel-hd"
			}
			else
			{				
				$url=$gameroms[0]."wheel"
			}
		}
		## Check if normalized video is available
		elseif ( $media.tag -eq "video" )
		{
			$video_normalized=$gameroms[0]."video-normalized"
			
			if ( $video_normalized -ne $null )
			{
				$url=$video_normalized
			}
		}
		# Check if bezel is available and generates inifile
		elseif ( $media.tag -eq "bezel-16-9" )
		{
			$bezelinipath=$mediapath+"\"+$media.destpath+"\"+$RLsystem+"\"+$romname+"\bezel.ini"
			$testpath=Test-Path -LiteralPath "$bezelinipath" -PathType Leaf
			
			if ( $testpath -eq $False -and !( $url -eq "" -or $url -eq $null ) )
			{										
				$bezelpath=$mediapath+"\"+$media.destpath+"\"+$RLsystem+"\"+$romname
				$testpath=Test-Path -LiteralPath "$bezelpath" -PathType Container
				
				if ( $testpath -eq $False )
				{										
					& mkdir $bezelpath | Out-Null
				}
				
				#Set-content "$bezelinipath" -value "$bezelini"
			}
			
			$dest=$mediapath+"\"+$media.destpath+"\"+$RLsystem+"\"+$romname+"\bezel."+$media.extension
		}
		#$url
		
		DownloadMedia "$url" "$dest"
		
	}
}

write-host "Generating AttractMode emulator cfg for current system..."
	
$testcfg=Test-Path -LiteralPath "$AMemucfg" -PathType Leaf

if ( $testcfg -eq $False )
{
	$cfgout=""
	$cfgout+="executable                 "+$RLexe+"`r`n"
	$cfgout+="args                       args -s `"[emulator]`" -r `"[name]`" -p AttractMode -f `""+$AMexe+"`"`r`n"
	$cfgout+="rompath                    Y:\roms\"+$RLsystem+"`r`n"
	$cfgout+="romext                     .7z`r`n"
	foreach ( $meta in $mediadata )
	{
		$cfgout+="artwork    "+$meta.AMart+"          y:\media\"+$meta.destpath+"\"+$RLsystem+"`r`n"
	}
	Set-content "$AMemucfg" -value "$cfgout"
}


write-host "Adding system config to AttractMode cfg file..."

$AMcfg = Get-Content "$AMcfgpath" -encoding utf8 | Where-Object { $_.Contains("$RLsystem") }
if ( $AMcfg -eq $null )
{
	$cfgout=""
	$cfgout+="display	"+$RLsystem+"`r`n"
	$cfgout+="layout               "+$RLsystem+"`r`n"
	$cfgout+="romlist              "+$RLsystem+"`r`n"
	$cfgout+="in_cycle             yes`r`n"
	$cfgout+="in_menu              yes`r`n"
	$cfgout+="filter               All`r`n"
	$cfgout+="filter               Favourites`r`n"
	$cfgout+="rule                 Favourite equals 1`r`n"
	$cfgout+="param                wheel_logo_size Smaller`r`n"
	Add-content "$AMcfgpath" -value "$cfgout" -encoding utf8
}

write-host "Generating RocketLauncher ini..."
	
$testini=Test-Path -LiteralPath "$RLemuini" -PathType Leaf

if ( $testini -eq $False )
{
	$null=New-Item -ItemType Directory -Force -Path $("$RLemuini" | Split-Path )
	$iniout=""
	$iniout+="[ROMS]`r`n"
	$iniout+="Default_Emulator="+"$RLmodule"+"`r`n"
	$iniout+="Rom_Path=..\..\roms\"+$RLsystem+"`r`n"
	Set-content "$RLemuini" -value "$iniout"
}

$romnum=$gameidlist.count

WriteLog "Finish scrapping!"
write-host "/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\"
write-host ------------------------------------------------------
write-host  "Total games: "$romnum
write-host ------------------------------------------------------
write-host "Current script run:"
write-host "-------------------"
write-host "Total media: "$global:totalmedia
write-host "Downloaded media: "$global:downloadedmedia
write-host "Unavailable media: "$global:notfoundmedia
$elapsedTime = $(get-date) - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
write-host "Elapsed time: "$totalTime
write-host ------------------------------------------------------

write-host "Process finish: "$(get-date)