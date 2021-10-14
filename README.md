# LiveSplit Files / Auto Splitter for Thargoid Interceptors in Elite Dangerous

These files enable you to automatically time your Thargoid interceptor fights with LiveSplit.

Don’t know what “Thargoid interceptors” are? You’re probably not playing Elite
Dangerous then.

Don’t know what [“LiveSplit”](https://livesplit.org) is? It allows you to time
speedruns of your favourite games!

## Setup

1. Download LiveSplit from https://livesplit.org/downloads/ and unzip it to a directory of your choosing;
2. Download this repository (green button in the top right of the repostory view → “Download ZIP”)
   and extract it to a directory of your choosing;
3. Launch Elite:Dangerous and from the Main Menu (Note: NOT when logged into Open/PG/Solo!) enable netlogs in-game in “Options” → “Networking”;
4. Launch LiveSplit and, in LiveSplit, do the following:
   - Right click, Open Splits, select [your choice of goid variant, e.g. Medusa].lss;
   - Right click, Open Layout, select [your choice of goid variant, e.g. Medusa].lsl;
   - Right click, Edit Layout, Layout Settings, then in Scriptable Auto Splitter, set Thargoid_Interceptor.asl as the script path;
5. [Optional] If you want to ensure the LiveSplits window is visible on top of your game screen, configure Elite:Dangerous to run in "borderless" (NOT "fullscreen")
   mode under the game's "Options" → "Graphics" → "Display" options; [Note: If you don't do this, LiveSplits will still work just fine, it will just run in the background];
6. You're good to go! LiveSplit will now automatically record your battle time and splits.

## Recording a Run

1. Load the correct splits file (*.lss) for the interceptor variant you are about to fight;
2. Load the correct layout file (*.lsl) for the interceptor variant you are about to fight;
3. Happy hunting!

Please be aware that your attempts and associated times will be saved to the
selected splits file. You may want to create copies of your splits files
if you are going to perform a variety of different activities/challenges.

## Known issues and limitations

1. LiveSplit will appear to "freeze" for 15 seconds when Elite Dangerous is loaded - this is (unfortunately) by design,
   as we need to wait for the appropriate log files to be created before we can open them;
2. Wing fights are currently not supported; this is due to how E:D writes log files; it will be fixed in an upcoming release.

If you encouter an issue other than the above, you can enable logging in the autosplitter script tab, to help diagnose the issue.

## Changelog

v1.0RC - Initial Release Candidate 10/14/2021

## Contributing authors

CMDR Abexuro, Discord: Abex#5089: Original creator for Eye of the Odyssey
CMDR alterNERDtive: Major overhaul of several systems and general "professionalization" of the code, initial README.md file
CMDR Mechan: Adaptation to general speedrunning, inclusion of netLog parsing, adding icons, updates to README.md file
CMDR Orodruin: Update for EotO and adaptation to Ceres Trials

