/*	Originally written, and successfully refactored, by CMDR Abexuro, Discord: Abex#5089
*	Edited/updated/adapted by CMDRs Mechan and Orodruin
*	"Professionalized" by CMDR alterNERDtive
*/

// Defines the process to monitor. We are not reading anything from the game’s memory, so it’s empty.
// We still need it though, LiveSplit will only run the auto splitter if the corresponding process is present.
// see https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#state-descriptors
state("EliteDangerous64") {}

// Executes when LiveSplit (re-)loads the auto splitter. Does general setup tasks.
// see https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#script-startup
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
	settings.Add("flushlog", false, "Flush the log file on every write", "logging");
	settings.SetToolTip("flushlog", "By default, log output is buffered to save I/O delay. Enable this for debugging, do not enable this for actual competitive runs.");

	vars.logFile = null;
	vars.logFileWriter = null;
	vars.logToFile = false;
	vars.logAutoFlush = false;
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
				vars.logFileWriter.WriteLine(System.DateTime.Now.ToString("dd/MM/yy hh:mm:ss:fff") + ": " + logLine);
				// We are not `Flush()`ing here by default to keep I/O delay down.
				// That means it is potentially only written when the auto splitter is un-/re-loaded, or when the timers are reset.
				if (vars.logAutoFlush) {
					vars.logFileWriter.Flush();
				}
			}
			catch (Exception e) {
				print(e.Message);
			}
		}
	});

	vars.log("Autosplitter loaded");
}

// Executes when LiveSplit detects the game process (see “state” at the top of the file).
// In our case the journal and netlog files are unique to every execution of the game, so we need to prepare them here.
// We also need to check if file logging is enabled (the setting is not available in `startup`) and create/open our log file.
// see https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#script-initialization-game-start
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
				vars.logAutoFlush = settings["flushlog"];
				try {
					string logDir = Path.GetDirectoryName(vars.logFile.FullName);
					if (!Directory.Exists(logDir)) {
						Directory.CreateDirectory(logDir);
					}

					if (vars.logFile.Exists) {
						vars.logFileWriter = vars.logFile.AppendText();
					}
					else {
						vars.logFileWriter = vars.logFile.CreateText();
					}
				}
				catch (Exception e) {
					MessageBox.Show("Could not create log file:\n" + vars.logFile.FullName);
				}
			}
			else {
				vars.logFileWriter.Close();
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

// Executes as long as the game process is running, by default 60 times per second.
// Unless explicitly returning `false`, `start`, `split` and `reset` are executed right after.
// See https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#generic-update
update {
	current.journalString = vars.journalReader.ReadToEnd();
	current.netlogString = vars.netlogReader.ReadToEnd();
}

// Executes every `update`. Starts the timer if Thargoid combat is detected.
// see https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#automatic-timer-start-1
start {
	bool start = false;

	if (!String.IsNullOrEmpty(current.journalString)) {
		System.Text.RegularExpressions.Match match = vars.journalEntries["start"].Match(current.journalString);
		if (match.Success) {
			// This is necessary if file logging was enabled in the layout settings _after_ the game was started.
			vars.setupLogging();

			vars.log(match.Groups["timestamp"].Value + " - Start run: Combat music detected");
			start = true;
		}
	}

	return start;
}

// Executes every `update`. Triggers a split if either a heart reset or a combat bond is detected.
// Caveat: We cannot distinguish between a destroyed and an un-exerted heart after the exert timer running out.
// Instead we split on heart reset, which occurs approximately 10s after destruction.
// This can run into a race condition with the killing blow occuring too fast after heart 4 destruction on a Cyclops, see #8
// see https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#automatic-splits-1
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

// Executes every `update`. Triggers a reset if a low or high wake is detected.
// see https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#automatic-resets-1
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

	// flush the log file
	if (vars.logFileWriter != null) {
		vars.logFileWriter.Flush();
	}

	return reset;
}

// Executes when the game process is shut down.
// In our case we’re going to close the files we opened in `init`.
// See https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#game-exit
exit {
	// Remember to mirror changes here in `shutdown` if necessary!

	vars.log("Elite client shut down, closing files …");
	
	vars.journalReader.Close();
	vars.netlogReader.Close();

	// flush the log file
	if (vars.logFileWriter != null) {
		vars.logFileWriter.Flush();
	}
}

// Executes when LiveScript shuts the auto splitter down, e.g. on reloading it.
// In our case we need to close the StreamWriter for the auto splitter’s log file.
// When reloading the splitter with the game running, LiveSplit does **not** execute `exit`, but it does execute `shutdown`.
// So we need to close the journal/netlog file readers here, too.
// see https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md#script-shutdown
shutdown {
	vars.log("Autosplitter is being shut down, closing streams …");

	if (vars.journalReader != null) {
		vars.journalReader.Close();
	}
	if (vars.netlogReader != null) {
		vars.netlogReader.Close();
	}

	// Close the log file writer.
	if (vars.logFileWriter != null) {
		vars.logFileWriter.Close();
	}
}
