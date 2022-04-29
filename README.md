# ss_autoscrape
Scrape rom media and info from Screenscraper.fr and creates structures for AttractMode and RocketLauncher with some Powershell scripts.

The current project is intended to check a full downloaded romset, from any platform, scan it for getting the info from Screenscraper.fr and generating a collection with only one game of each in the platform based on region preferences. Actually is configured to get roms in this order:

("es","sp","eu","wor","us","en","uk","ame","ss","jp")

There are 2 main scripts:

singlescrape.ps1:

  This script checks all the roms from the desired folder and creates a collection of unique games based on region preferences. The main specs are the followint:
  - Gets the systems info xml with all info and metadata.
  - Checks folder and subfolders if the game is multirom (subfolder).
  - Gets each rom XML with all game data and media links for downloading (wheels, fanart, bezels,...)
  - If there is no subfolder for multirom games the script uses rom information from Screenscraper to determine if is a multirom game or not.
  - Stores into an XML file all game collection info for further 
