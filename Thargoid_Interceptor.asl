/*	Originally written, and successfully refactored, by CMDR Abexuro, Discord: Abex#5089
*	Edited/updated/adapted by CMDRs Mechan and Orodruin
*	"Professionalized" by CMDR AlterNERDtive
*
*	### INSTALLATION ###
*	-	If you haven't already, download LiveSplit from https://livesplit.org/downloads/
*	-	Enable netLogs in-game in the main_menu/networking screen
*	-	In LiveSplit do the following:
*	-		Right click, Open Splits, select the appropriate *.lss file (Cyclops/Basilisk/Medusa/Hydra)
*	-		Right click, Open Layout, select the appropriate *.lsl file (Cyclops/Basilisk/Medusa/Hydra)
*	-		Right click, Edit Layout, Layout Settings, then in Scriptable Auto Splitter, set the appropriate *.asl file as the script path (Cyclops/Basilisk/Medusa/Hydra)
*
*/

state("EliteDangerous64") {}

startup {
	// Relevant journal entries
	vars.journalEntries = new Dictionary<string, System.Text.RegularExpressions.Regex>();
	vars.journalEntries["start"] =
		new System.Text.RegularExpressions.Regex(@"\{ ""timestamp"":""(?<timestamp>.*)"", ""event"":""Music"", ""MusicTrack"":""Combat_Unknown"" \}");
	vars.journalEntries["end"] =
		new System.Text.RegularExpressions.Regex(@"\{ ""timestamp"":""(?<timestamp>.*)"", ""event"":""FactionKillBond"", ""Reward"":(?<reward>\d{7}\d?), ""AwardingFaction"":""\$faction_PilotsFederation;"", ""AwardingFaction_Localised"":"".*"", ""VictimFaction"":""\$faction_Thargoid;"", ""VictimFaction_Localised"":"".*"" \}");
	vars.journalEntries["reset"] = new System.Text.RegularExpressions.Regex(@".*(SupercruiseEntry|StartJump.*JumpType.*Hyperspace).*");

	// Relevant netlog entries
	vars.netlogEntries = new Dictionary<string, System.Text.RegularExpressions.Regex>();
	vars.netlogEntries["heart"]
		= new System.Text.RegularExpressions.Regex(@"\{(?<timestamp>.*)\} HeartManager - Authority SetExertedHeartSlotIndex: (?<index>\d+) \(\d+\)");

	// readers
	vars.journalReader = null;
	vars.netlogReader = null;
	// Initialize heart counter
	vars.heartCounter = 0;
	// Initialize settings
	settings.Add("logging", false, "Log to file");
	settings.SetToolTip("logging", "Write the auto splitter log to a file for debugging purposes");

	vars.logFile = null;
	vars.logToFile = false;
	// Initialize log file
	vars.logFile = new FileInfo(Path.Combine(
			Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
			"LiveSplit",
			"Thargoid_Interceptors",
			"autosplitter.log")
		);
	vars.log = (Action<string>)((string logLine) => {
		print(logLine);
		if (vars.logToFile) {
			try {
				using (StreamWriter writer = vars.logFile.AppendText()) {
					writer.WriteLine(System.DateTime.Now.ToString("dd/MM/yy hh:mm:ss:fff") + ": " + logLine);
				}
			}
			catch (Exception e) {
				print(e.Message);
			}
		}
	});

	vars.log("Autosplitter loaded");
}

init {
	// Doing this here, since the setting is not available during `startup`.
	// There is no way to detect when the user changes the option in layout settings; so we’ll have to check in `start` again.
	// If a user changes the setting mid run … not my department.
	vars.setupLogging = (Action)delegate() {
		// Only do anything if the setting hasn’t been applied yet.
		// If we’re in sync, just return to minimise execution time.
		if (settings["logging"] != vars.logToFile) {
			vars.logToFile = settings["logging"];
			if (vars.logToFile) {
				try {
					string logDir = Path.GetDirectoryName(vars.logFile.FullName);
					if (!Directory.Exists(logDir)) {
						Directory.CreateDirectory(logDir);
					}
					if (!vars.logFile.Exists) {
						vars.logFile.Create();
					}
				}
				catch (Exception e) {
					MessageBox.Show("Could not create log file:\n" + vars.logFile.FullName);
				}
			}
		}
	};
	vars.setupLogging();

	// There will be a process, otherwise this wouldn’t be called. There will only be one process of that file.
	string eliteClientPath = Process.GetProcessesByName("EliteDangerous64").First().MainModule.FileName;
	vars.log("Found Elite Process: " + eliteClientPath);

	string netlogPath = Path.Combine(
			Path.GetDirectoryName(eliteClientPath),
			"Logs"
		);
	string journalPath = Path.Combine(
		Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
		"Saved Games",
		"Frontier Developments",
		"Elite Dangerous"
		);

	// Quick & dirty race condition “fix”, see issue #4
	int delay = 15;
	vars.log("Waiting for log files, sleeping for " + delay + " s …");
	Thread.Sleep(delay*1000);

	// Grab latest journal file
	FileInfo journalFile = new DirectoryInfo(journalPath).GetFiles("journal.*.log").OrderByDescending(file => file.Name).First();
	vars.log("Found Journal: " + journalFile.FullName);
	vars.journalReader = new StreamReader(new FileStream(journalFile.FullName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
	vars.journalReader.ReadToEnd();

	// Grab latest netlog file
	if (!Directory.Exists(netlogPath)) {
		string message = "Netlog directory '" + netlogPath + "' not found. Please make sure to enable netlogs.";
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
	current.journalString = vars.journalReader.ReadToEnd();
	current.netlogString = vars.netlogReader.ReadToEnd();

	if (String.IsNullOrEmpty(current.journalString) && String.IsNullOrEmpty(current.netlogString)) {
		// Nothing new, don't run any other code blocks
		return false; 
	}
}

start {
	bool start = false;

	if (!String.IsNullOrEmpty(current.journalString)) {
		System.Text.RegularExpressions.Match match = vars.journalEntries["start"].Match(current.journalString);
		if (match.Success) {
			// This is necessary if file logging was enabled in the layout settings _after_ the game was started.
			// There appears to be a race condition here; creating the file, then immediately trying to log to it results in:
			// “[XXXXX] The process cannot access the file '…\autosplitter.log' because it is being used by another process.”
			// We can’t wait either though, it would delay the start time.
			vars.setupLogging();

			vars.log(match.Groups["timestamp"].Value + " - Start run: Combat music detected");
			start = true;
		}
	}

	return start;
}

split {
	bool split = false;

	if (!String.IsNullOrEmpty(current.netlogString)) {
		System.Text.RegularExpressions.Match match = vars.netlogEntries["heart"].Match(current.netlogString);
		if (match.Success && match.Groups["index"].Value == "4294967295") {
			vars.log(match.Groups["timestamp"].Value + " - Split: Heart " + ++vars.heartCounter + " down");
			split = true;
		}
	}
	
	if (!String.IsNullOrEmpty(current.journalString)) {
		System.Text.RegularExpressions.Match match = vars.journalEntries["end"].Match(current.journalString);
		if (match.Success) {
			vars.log(match.Groups["timestamp"].Value + " - Finish run: Bond received");
			split = true;
		}
	}

	return split;
}

reset {
	bool reset = false;

	if (!String.IsNullOrEmpty(current.journalString)) {
		System.Text.RegularExpressions.Match match = vars.journalEntries["reset"].Match(current.journalString);
		if (match.Success) {
			vars.log(match.Groups["timestamp"].Value + " - Reset: Jumped out");
			reset = true;
		}
	}

	// Reset heart counter for next fight
	if (reset) {
		vars.heartCounter = 0;
	}

	return reset;
}

exit {
	// we opened these on game launch, so we better close them on game shutdown!
	vars.journalReader.Close();
	vars.netlogReader.Close();
}
