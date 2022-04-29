# ss_autoscrape
Scrape rom media and info from Screenscraper.fr and creates structures for AttractMode and RocketLauncher with some Powershell scripts.

ATTENTION!!! A DEVELOPMENT ACCOUNT IN Screenscraper.fr IS NEEDED TO USE THIS SCRIPTS!!!!!!

The current project is intended to check a full downloaded romset, from any platform, scan it for getting the info from Screenscraper.fr and generating a collection with only one game of each in the platform based on region preferences. Actually is configured to get roms in this order:

("es","sp","eu","wor","us","en","uk","ame","ss","jp")

There are 2 main scripts:

singlescrape.ps1:

  This script checks all the roms from the desired folder and creates a collection of unique games based on region preferences. The main specs are the following:
  - Gets the all systems info xml (media links, company, release date, romtype, rom extension,...).
  - Checks folder and subfolders (for multirom games if they are in subfolders).
  - Gets each rom XML with all game data and media links for downloading (wheels, fanart, bezels,...)
  - If there is no subfolder for multirom games the script uses rom information from Screenscraper to determine if is a multirom game or not (romnumsupport field in rom XML file).
  - Stores one XML file for each rom.
  - Discards BETAS, BIOS, DEMOS and HACKS based on filename and retrieved rom info.
  - Script runs with a simple form where you must select original system (combo loaded from systems.xml downloaded from Screenscraper.fr) and the roms folder.

![image](https://user-images.githubusercontent.com/39946894/165933120-c30c7c84-dfeb-4adc-9b46-8ca5ad995529.png)

There are some variables that have to be filled before first run:

  $ssid="" # Your Screenskraper user
  $sspassword="" # Your Screenskraper pass
  $devid="" # Your Screenskraper development user
  $devpassword="" # Your Screenskraper development pass
  $softname="" # The name of the software. This is not relevant
  # --------------------------------------------
  $roms_orig='' # Default roms source folder
  $system='' # Default system to scrape
  $regionorder=@("es","sp","eu","wor","us","en","uk","ame","ss","jp") # Desired order region for getting each game
  
  When finished it stores an XML with the scrapped system name containing all collection data, ready to be read by the second script.
  

parse_xml.ps1
  
  This script parses the XML generated by singlescrape.ps1:
  - Copys all desired roms to desired destination folder, creating subfolders for multirom games.
  - Generates m4u files for multirom games.
  - Downloads all media scrapped for each rom into its folder (wheel, fanart, bezel, videos...).
  - Creates cfg file for each emulator into AttractMode folder.
  - Adds the screen to AttractMode cfg file to show in menus.
  - Creates RocketLauncher ini file, needed by AttractMode to run the roms for each system.

  There is a simple form that asks for needed information each run:

![image](https://user-images.githubusercontent.com/39946894/165934520-3916f052-f525-464c-a84f-668f840deef4.png)

  - The first combo is a list with all systems xml files generated by singlescrape.ps1. It is the source collection.
  - The second combo asks for RocketLauncher module, readed from modules folder in RocketLauncher.
  - The third combo shows all systems included for selected RL module.

There are some variables that have to be filled before first run:

- This is for bezel adjust, it depends on the downloaded bezel and must be checked after process finishes
# -----------------------------------------------
$bezelini+="[General]`r`n"
$bezelini+="Bezel Screen Top Left X Coordinate=250`r`n"
$bezelini+="Bezel Screen Top Left Y Coordinate=13`r`n"
$bezelini+="Bezel Screen Bottom Right X Coordinate=1670`r`n"
$bezelini+="Bezel Screen Bottom Right Y Coordinate=1070`r`n"
# -----------------------------------------------

$xmlfolder="" # Folder where the XML source collections are stored. Must be full path
$RLpath="" # RocketLauncher folder. Must be full path
$RLRAmodule=$RLpath+"\Modules"
$regionorder=@("es","sp","eu","wor","us","en","uk","ame","ss","jp") # Desired order region for getting each game  
$romdestfolder="" # Roms destination folder. Must be full path
$mediapath="Y:\media" # Media destination folder (with AM structure). Must be full path
$7zpath="..\..\7z\7z.exe" # Location of 7z executable. Could be relative path
$AMpath="Y:\Software\Attract Mode" # AttractMode path. Must be full path.
$RLdefaultmodule="RetroArch" # Default module to show in the combo.

Final thoughts:

The code is ugly, this is my first approach to XML and Powershell, all rutines can be upgraded with better performance and I use Powershell ojbects like I have never used them :D but it works!! I have tested with multiple romsets and seems to run OK, but there is a looooot of work to do!

Hope someone find this scrits interesting and useful. If anyone wants to collaborate with me I will be here to hear your wishes!!

Thanks all!

