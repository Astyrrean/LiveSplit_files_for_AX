/*	Originally written, and successfully refactored, by CMDR Abexuro, Discord: Abex#5089
*	Edited/updated/adapted by CMDRs Mechan and Orodruin
*	"Professionalized" by CMDR AlterNERDtive
*
*	### INSTALLATION ###
*	-	If you haven't already, download LiveSplit from https://livesplit.org/downloads/
*	-	Enable netLogs in-game in the main_menu/networking screen
*	-	In this file, set vars.installationFolder in the "startup" section to point to your Launcher installation folder.
*	-	In LiveSplit do the following:
*	-		Right click, Open Splits, select the appropriate *.lss file (Cyclops/Basilisk/Medusa/Hydra)
*	-		Right click, Open Layout, select the appropriate *.lsl file (Cyclops/Basilisk/Medusa/Hydra)
*	-		Right click, Edit Layout, Layout Settings, then in Scriptable Auto Splitter, set the appropriate *.asl file as the script path (Cyclops/Basilisk/Medusa/Hydra)
*
*/

state("EliteDangerous64") {}

startup {
	vars.installationFolder = @"x:\path\to\edlaunch";

	// Set up regular expressions for start, split, and reset
	vars.startMusicRegex = new System.Text.RegularExpressions.Regex(".*MusicTrack.*Combat_Unknown.*");
	vars.splitHeartRegex = new System.Text.RegularExpressions.Regex(".*HeartManager.*SetExertedHeartSlotIndex.*4294967295.*");
	vars.splitBondRegex = new System.Text.RegularExpressions.Regex(".*FactionKillBond.*faction_Thargoid.*");
	vars.resetSupercruiseRegex = new System.Text.RegularExpressions.Regex(".*SupercruiseEntry.*");
	vars.resetHyperspaceRegex = new System.Text.RegularExpressions.Regex(".*StartJump.*JumpType.*Hyperspace.*");

	// Initialize heart counter
	vars.heartCounter = 0;
	// Initialize settings
	settings.Add("odyssey", false, "Odyssey client");
	settings.SetToolTip("odyssey", "Enable this if you are loaded into Odyssey, keep this disabled if you are loaded into Horizons");
	
	// Initializize LiveSplit's own log file
	vars.logFilePath = "C:\\Users\\FScog\\Saved Games\\autosplitter_elite.log";
	vars.log = (Action<string>)((string logLine) => {
		print(logLine);
		string time = System.DateTime.Now.ToString("dd/MM/yy hh:mm:ss:fff");
		System.IO.File.AppendAllText(vars.logFilePath, time + ": " + logLine + "\r\n");
	});
	try {
		vars.log("Autosplitter loaded");
	} catch (System.IO.FileNotFoundException e) {
		System.IO.File.Create(vars.logFilePath);
		vars.log("Autosplitter loaded, log file created");
	}
}

init {
	// Open Journal - Edit journalPath to match where your journal file is
	string journalPath = Path.Combine(
		Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
		"Saved Games",
		"Frontier Developments",
		"Elite Dangerous"
		);
	FileInfo journalFile = new DirectoryInfo(journalPath).GetFiles("journal.*.log").OrderByDescending(file => file.Name).First();
	vars.log("Found Journal: " + journalFile.FullName);
	vars.journalReader = new StreamReader(new FileStream(journalFile.FullName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
	vars.journalReader.ReadToEnd();

	// Open netLog - Edit netLogPath to match where your netLog file is, and note it varies between Horizons and Odyssey!
	string netlogPath = Path.Combine(
			vars.installationFolder,
			"Products",
			(settings["odyssey"] ? "elite-dangerous-64-odyssey" : "elite-dangerous-64"), // FIXXME: check that
			"Logs"
		);
	if (!Directory.Exists(netlogPath)) {
		string message = "Netlog directory '" + netlogPath + "' not found. Please make sure to set your game installation folder and enable netlogs.";
		vars.log(message);
		MessageBox.Show(message);
	} else {
		FileInfo netLogFile = new DirectoryInfo(netlogPath).GetFiles("netLog.*.log").OrderByDescending(file => file.Name).First();
		vars.log("Found NetLog: " + netLogFile.FullName);
		vars.netlogReader = new StreamReader(new FileStream(netLogFile.FullName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
		vars.netlogReader.ReadToEnd();
	}
}

update {
	vars.journalString = vars.journalReader.ReadToEnd();
	vars.netlogString = vars.netlogReader.ReadToEnd();
	if (vars.journalString == null && vars.netlogString == null) return false; // Nothing new, don't run any other code blocks
}

start {
	if (vars.startMusicRegex.Match(vars.journalString).Success) {
		vars.log("Start run: Combat music detected");
		return true; // Combat started
	} else {
		return false;
	}
}

split {
	if (vars.journalString == null && vars.netlogString == null) return false; // Nothing new, don't run this block

	if (vars.splitHeartRegex.Match(vars.netlogString).Success) {
		vars.log("Split: Heart " + ++vars.heartCounter + " down");
		return true;
	}
	if (vars.splitBondRegex.Match(vars.journalString).Success) {
		vars.log("Finish run: Bond received");
		return true;
	}
}

reset {
	if (vars.resetSupercruiseRegex.Match(vars.journalString).Success) {
		vars.log("Reset: Jumped to Supercruise");
		return true;
	}

	if (vars.resetHyperspaceRegex.Match(vars.journalString).Success) {
		vars.log("Reset: Jumped to Hyperspace");
		return true;
	}

	// NOTE: As alterNERDtive suggested, need to add more reset conditions such as rebuy here ... TBD --CMDR Mechan

}

exit {
	// we opened these on game launch, so we better close them on game shutdown!
	vars.journalReader.Close();
	vars.netlogReader.Close();
}