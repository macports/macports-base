/*
	daemondo - main.c
	
	Copyright (c) 2005 James Berry <jberry@macports.org>
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions
	are met:
	1. Redistributions of source code must retain the above copyright
	   notice, this list of conditions and the following disclaimer.
	2. Redistributions in binary form must reproduce the above copyright
	   notice, this list of conditions and the following disclaimer in the
	   documentation and/or other materials provided with the distribution.
	3. Neither the name of Apple Computer, Inc. nor the names of its contributors
	   may be used to endorse or promote products derived from this software
	   without specific prior written permission.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.

	$Id$
*/

/*
	Potentially useful System Configuration regex patterns:

		(backslash quoting below is only to protect the C comment)
		State:/Network/Interface/.*\/Link 
		State:/Network/Interface/.*\/IPv4
		State:/Network/Interface/.*\/IPv6
		
		State:/Network/Global/DNS
		State:/Network/Global/IPv4
		
	Potentially useful notifications from Darwin Notify Center:
	
		com.apple.system.config.network_change
*/

/*
	New parameters:
	
		--pid=none		- no pid is available; we start/stop only through the commands,
						  and have no real knowledge of whether the process is running
		--pid=exec		- we track the pid we receive from exec of the start cmd
		--pid=fileauto	- we track the pid available in first word of pidfile
		--pid=fileclean	- we track the pid available in first word of pidfile,
						  and clean it up when the process dies
		
		--pidfile=name	- the name of the pidfile to use
*/
	
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <getopt.h>
#include <fcntl.h>
#include <stdarg.h>
#include <time.h>
#include <sys/wait.h>
#include <mach/mach.h>

#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

// Constants
const CFTimeInterval kRestartHysteresis	= 5.0;		// Five seconds of hysteresis
const CFTimeInterval kChildDeathTimeout = 20.0;
const CFTimeInterval kChildStartPidTimeout = 30.0;

typedef enum {
	kPidStyleUnknown = 0,
	kPidStyleNone,
	kPidStyleExec,
	kPidStyleFileAuto,
	kPidStyleFileClean
} PidStyle;

// Globals
CFStringRef			kProgramName		= NULL;
CFStringRef			kChildWatchMode		= NULL;

int					verbosity			= 0;		// Verbosity level
const char*			label				= NULL;

const char* const*	startArgs			= NULL;		// Argvs for start-cmd, stop-cmd, and restart-cmd
const char* const*	stopArgs			= NULL;
const char* const*	restartArgs			= NULL;

PidStyle			pidStyle			= kPidStyleUnknown;
const char*			pidFile				= NULL;

int					terminating			= 0;		// TRUE if we're terminating
pid_t				runningPid			= 0;		// Current running pid (0 while stopped, -1 if we don't know pid)

mach_port_t			sigChild_m_port		= 0;		// Mach port to send signals through
mach_port_t			sigGeneric_m_port	= 0;		// Mach port to send signals through

CFMutableArrayRef	scRestartPatterns	= NULL;		// Array of sc patterns to restart daemon on
CFMutableArrayRef	distNotifyNames		= NULL;		// Array of distributed notification names to restart daemon on
CFMutableArrayRef	darwinNotifyNames	= NULL;		// Array of darwin notification names to restart daemon on

io_connect_t		pwrRootPort			= 0;
int					restartOnWakeup		= 0;		// TRUE to restart daemon on wake from sleep
CFRunLoopTimerRef	restartTimer		= NULL;		// Timer for scheduled restart


void
LogMessage(const char* fmt, ...)
{
	struct tm tm;
	time_t timestamp;
	char datestring[32];
	
	// Format the date-time stamp
	time(&timestamp);
	strftime(datestring, sizeof(datestring), "%F %T", localtime_r(&timestamp, &tm));
	
	// Output the log header
	if (label != NULL)
		printf("%s %s: ", datestring, label);
	else
		printf("%s ", datestring);
	
	// Output the message
	va_list ap;
	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	
	printf("\n");
}


void
DoVersion(void)
{
	printf("daemondo, version 1.0d2\n\n");
}


void
DoHelp(void)
{
	DoVersion();
	
	const char* helpText =
		"usage: daemondo [-hv] [--version]\n"
		"                     --start-cmd prog args... ;\n"
		"                     [--stop-cmd prog arg... ;]\n"
		"                     [--restart-cmd prog arg... ;]\n"
		"                     [--restart-wakeup]\n"
		"                     [--restart-netchange]\n"
		"\n"
		"daemondo is a wrapper program that runs daemons. It starts the specified\n"
		"daemon on launch, stops it when given SIGTERM, and restarts it on SIGHUP.\n"
		"It can also watch for transitions in system state, such as a change in\n"
		"network availability or system power state, and restart the daemon on such\n"
		"an event.\n"
		"\n"
		"daemondo works well as an adapter between darwin 8's launchd, and daemons\n"
		"that are normally started via traditional rc.d style scripts or parameters.\n"
		"\n"
		"Parameters:\n"
		"\n"
		"  -h, --help                      Provide this help.\n"
		"  -v                              Increase verbosity.\n"
		"      --verbosity=n               Set verbosity to n.\n"
		"  -V, --version                   Display program version information.\n"
		"  -l, --label=desc                Label used to describe the daemon.\n"
		"\n"
		"  -s, --start-cmd args... ;       Required: command that will start the daemon.\n"
		"  -k, --stop-cmd args... ;        Command that will stop the daemon.\n"
		"  -r, --restart-cmd args... ;     Command that will restart the daemon.\n"
		"      --restart-config regex... ; SC patterns on which to restart the daemon.\n"
		"      --restart-dist-notify names... ;\n"
		"                                  Distributed Notification Center notifications\n"
		"                                  on which to restart the daemon.\n"
		"      --restart-darwin-notify names... ;\n"
		"                                  Darwin Notification Center notifications\n"
		"                                  on which to restart the daemon.\n"
		"      --restart-config regex... ; SC patterns on which to restart the daemon.\n"
		"      --restart-wakeup            Restart daemon on wake from sleep.\n"
		"      --restart-netchange         Restart daemon on a network change.\n"
		"\n"
		"daemondo responds to SIGHUP by restarting the daemon, and to SIGTERM by\n"
		"stopping it. daemondo exits on receipt of SIGTERM, or when it detects\n"
		"that the daemon process has died.\n"
		"\n"
		"The arguments start-cmd, stop-cmd, restart-cmd, restart-config,\n"
		"restart-dist-notify, and restart-darwin-notify, if present,\n"
		"must each be followed by arguments terminated by a ';'. You may need to\n"
		"escape or quote the ';' to protect it from special handling by your shell.\n"
		"\n"
		"daemondo runs in one of two modes: (1) If no stop-cmd is given, daemondo\n"
		"executes start-cmd asyncronously, and tracks the process id; that process id\n"
		"is used to signal the daemon for later stop and/or restart. (2) If stop-cmd\n"
		"is given, then both start-cmd and stop-cmd are issued syncronously, and are\n"
		"assumed to do all the work of controlling the daemon. In such cases there is\n"
		"no process id to track. In either mode, restart-cmd, if present, is used to\n"
		"restart the daemon. If in mode 1, restart-cmd must not disrupt the process id.\n"
		"If restart-cmd is not provided, the daemon is restarted via a stop/start\n"
		"sequence.\n"
		"\n"
		"The argument restart-config specifies a set of regex patterns corresponding\n"
		"to system configuration keys, on notification of change for which the daemon\n"
		"will be restarted\n"
		"\n"
		"The arguments restart-dist-notify and restart-darwin-notify specify a set of\n"
		"notification names from the distributed and darwin notification centers,\n"
		"respectively, on receipt of which the daemon will be restarted.\n"
		"\n"
		"The argument restart-wakeup will cause the daemon to be restarted when the\n"
		"computer wakes from sleep.\n"
		"\n"
		"The argument restart-netchange will cause the daemon to be restarted when\n"
		"the network configuration changes. This is a shortcut for the more\n"
		"verbose --restart-darwin-notify com.apple.system.config.network_change.\n"
		"\n"
		"In mode 1 only, daemondo will exit when it detects that the daemon being\n"
		"monitored has exited.\n"
		"\n"
		;
		
	printf(helpText);
}


void
CreatePidFile(void)
{
	// Write a pid file if we're expected to
	if (pidFile != NULL)
	{
		FILE* f = NULL;
		switch (pidStyle)
		{
		default:
		case kPidStyleNone:			// No pid is available
		case kPidStyleFileAuto:		// The process should create its own pid file
		case kPidStyleFileClean:	// The process should create its own pid file
			break;
		case kPidStyleExec:			// We know the pid, and will write it to the pid file
			f = fopen(pidFile, "w");
			if (f != NULL)
			{
				fprintf(f, "%d", runningPid);
				fclose(f);
			}
			break;
		}
	}
}

void
DestroyPidFile(void)
{
	// Cleanup the pid file
	if (pidFile != NULL)
	{
		switch (pidStyle)
		{
		default:
		case kPidStyleNone:			// No pid is available
		case kPidStyleFileAuto:		// The process should remove its own pid file
			break;
		case kPidStyleExec:			// We wrote the file, and we'll remove it
		case kPidStyleFileClean:	// The process wrote the file, but we'll remove it
			unlink(pidFile);
			break;
		}
	}
}


pid_t
CheckForValidPidFile(void)
{
	// Try to read the pid from the pid file
	pid_t pid = -1;
	FILE* f = fopen(pidFile, "r");
	if (f != NULL)
	{
		if (1 != fscanf(f, "%d", &pid))
			pid = -1;
		if (pid == 0)
			pid = -1;
		fclose(f);
	}
	
	// Check whether the pid represents a valid process
	if (pid != -1 && 0 != kill(pid, 0))
		pid = -1;
	
	return pid;
}


pid_t
WaitForValidPidFile(void)
{
	CFAbsoluteTime patience = CFAbsoluteTimeGetCurrent() + kChildStartPidTimeout;
	
	// Poll for a child process and pidfile to be generated, until we lose patience.
	pid_t pid = -1;
	while ((pid = CheckForValidPidFile()) == -1 && (patience - CFAbsoluteTimeGetCurrent() > 0))
		sleep(1);

	return pid;
}


void
ProcessChildDeath(pid_t childPid)
{
	// Take special note if process runningPid dies
	if (runningPid != 0 && runningPid != -1 && childPid == runningPid)
	{
		if (verbosity >= 3)
			printf("Running process id %d has died.\n", childPid);
			
		DestroyPidFile();

		runningPid = 0;
		CFRunLoopStop(CFRunLoopGetCurrent());
	}
}


void
WaitChildDeath(pid_t childPid)
{
	// Wait for the death of a particular child
	int wait_result = 0;
	int wait_stat = 0;
	
	// Set up a timer for how long we'll wait for child death before we
	// kill the child outright with SIGKILL (infanticide)
	CFAbsoluteTime patience = CFAbsoluteTimeGetCurrent() + kChildDeathTimeout;
	
	// Wait for the death of child, calling into our run loop if it's not dead yet.
	// Note that the wait may actually be processed by our runloop callback, in which
	// case the wait here will simply return -1.
	while ((wait_result = wait4(childPid, &wait_stat, WNOHANG, NULL)) == 0)
	{
		CFTimeInterval patienceRemaining = patience - CFAbsoluteTimeGetCurrent();
		if (patienceRemaining > 0)
			CFRunLoopRunInMode(kChildWatchMode, patienceRemaining, true);
		else
		{
			// We've run out of patience; kill the child with SIGKILL
			if (verbosity >= 3)
				printf("Child %d didn't die; Killing with SIGKILL.\n", childPid);
			
			if (0 != kill(childPid, SIGKILL))
			{
				if (verbosity >= 3)
					printf("Attempt to kill process %d failed.\n", childPid);
			}
		}
	}
	
	// The child should be dead and gone by now.
	ProcessChildDeath(childPid);
}


void
CheckChildren(void)
{
	// Process any pending child deaths
	int wait_stat = 0;
	pid_t pid = 0;
	while ((pid = wait4(0, &wait_stat, WNOHANG, NULL)) != 0 && pid != -1)
		ProcessChildDeath(pid);
}


pid_t
Exec(const char* const argv[], int sync)
{
	if (!argv || !argv[0] || !*argv[0])
		return -1;
		
	pid_t pid = fork();
	switch (pid)
	{
	case 0:
		// In the child process
		{			
			// Child process has no stdin, but shares stdout and stderr with us
			// Is that the right behavior?
			int nullfd = 0;
			if ((nullfd = open("/dev/null", O_RDONLY)) == -1)
				_exit(1);
			dup2(nullfd, STDIN_FILENO);

			// Launch the child
			execvp(argv[0], (char* const*)argv);
			
			// We get here only if the exec fails.
			printf("Unable to launch process %s.\n", argv[0]);
			_exit(1);
		}
		break;
	
	case -1:
		// error starting child process
		printf("Unable to fork child process %s.\n", argv[0]);
		break;
	
	default:
		// In the original process
		if (sync)
		{
			// If synchronous, wait for the child process to complete
			WaitChildDeath(pid);
			pid = 0;
		}
		break;
	}
	
	return pid;
}


int
Start(void)
{	
	if (!startArgs || !startArgs[0])
	{
		printf("There is nothing to start. No start-cmd was specified.\n");
		return 2;
	}
	
	if (verbosity >= 1)
		LogMessage("starting process");
	if (verbosity >= 2)
		printf("Running start-cmd %s.\n", startArgs[0]);
		
	// Exec the start-cmd
	pid_t pid = Exec(startArgs, pidStyle == kPidStyleNone);
	
	// Process error during Exec
	if (pid == -1)
	{
		if (verbosity >= 2)
			printf("Error running start-cmd %s.\n", startArgs[0]);
		if (verbosity >= 1)
			LogMessage("error while starting");
		return 2;
	}
	
	// Try to discover the pid of the running process
	switch (pidStyle)
	{
	case kPidStyleNone:			// The command should have completed: we have no pid (should be zero)
		pid = -1;
		break;
		
	case kPidStyleExec:			// The pid comes from the Exec
		break;
		
	case kPidStyleFileAuto:		// Poll pid from the pidfile
	case kPidStyleFileClean:
		pid = WaitForValidPidFile();
		if (pid == -1)
		{
			if (verbosity >= 2)
				printf("Error; expected pidfile not found following Exec of start-cmd %s.\n", startArgs[0]);
			if (verbosity >= 1)
				LogMessage("error while starting");
			return 2;
		}
		break;
		
	default:
		break;
	}
	
	// If we have a pid, then begin tracking it
	runningPid = pid;
	if (pid != 0 && pid != -1)
	{
		if (verbosity >= 1)
			LogMessage("process id %d", pid);

		// Create a pid file if we need to		
		CreatePidFile();
	}
	
	return 0;
}


int
Stop(void)
{
	pid_t pid;
	if (!stopArgs || !stopArgs[0])
	{
		// We don't have a stop command, so we try to kill the process
		// we're tracking with runningPid
		if ((pid = runningPid) != 0 && pid != -1)
		{
			if (verbosity >= 1)
				LogMessage("stopping process %d\n", pid);
			
			// Send the process a SIGTERM to ask it to quit
			kill(pid, SIGTERM);
			
			// Wait for process to quit, killing it after a timeout
			WaitChildDeath(pid);
		}
		else
		{
			if (verbosity >= 1)
				LogMessage("process was already stopped");
		}
	}
	else
	{
		// We have a stop-cmd to use. We execute it synchronously,
		// and trust it to do the job.
		if (verbosity >= 1)
			LogMessage("stopping process");
		if (verbosity >= 2)
			printf("Running stop-cmd %s.\n", stopArgs[0]);
		pid = Exec(stopArgs, TRUE);
		if (pid == -1)
		{
			if (verbosity >= 2)
				printf("Error while running stop-cmd %s\n", stopArgs[0]);
			if (verbosity >= 1)
				LogMessage("error stopping process");
			return 2;
		}

		// We've executed stop-cmd, so we assume any runningPid process is gone
		runningPid = 0;
		DestroyPidFile();
	}
	
	return 0;
}


int
Restart(void)
{
	if (!restartArgs || !restartArgs[0])
	{
		// We weren't given a restart command, so just use stop/start
		if (verbosity >= 1)
			LogMessage("restarting process");
		Stop();
		Start();
	}
	else
	{
		// Execute the restart-cmd and trust it to do the job
		if (verbosity >= 1)
			LogMessage("restarting process");
		if (verbosity >= 2)
			printf("Running restart-cmd %s.\n", restartArgs[0]);
		pid_t pid = Exec(restartArgs, TRUE);
		if (pid == -1)
		{
			if (verbosity >= 2)
				printf("Error running restart-cmd %s\n", restartArgs[0]);
			if (verbosity >= 1)
				LogMessage("error restarting process");
			return 2;
		}
	}
	
	return 0;
}


void
ScheduledRestartCallback(CFRunLoopTimerRef timer, void *info)
{
	if (verbosity >= 3)
		printf("Scheduled restart time has arrived.\n");
		
	// Our scheduled restart fired, so restart now
	Restart();
}


void
CancelScheduledRestart(void)
{
	// Kill off any existing timer
	if (restartTimer)
	{
		if (CFRunLoopTimerIsValid(restartTimer))
			CFRunLoopTimerInvalidate(restartTimer);
		CFRelease(restartTimer);
		restartTimer = NULL;
	}
}


void
ScheduleRestartForTime(CFAbsoluteTime absoluteTime)
{
	// Cancel any currently scheduled restart
	CancelScheduledRestart();
	
	// Schedule a new restart
	restartTimer = CFRunLoopTimerCreate(NULL, absoluteTime, 0, 0, 0, ScheduledRestartCallback, NULL);
	if (restartTimer)
		CFRunLoopAddTimer(CFRunLoopGetCurrent(), restartTimer, kCFRunLoopDefaultMode);
}


void
ScheduleDelayedRestart(void)
{
	// The hysteresis here allows us to take multiple restart requests within a small
	// period of time, and coalesce them together into only one. It also allows for
	// a certain amount of "slop time" for things to stabilize following whatever
	// event is triggering the restart.
	if (verbosity >= 3)
		printf("Scheduling restart %f seconds in future.\n", kRestartHysteresis);
	ScheduleRestartForTime(CFAbsoluteTimeGetCurrent() + kRestartHysteresis);
}


void
DynamicStoreChanged(
					SCDynamicStoreRef	store,
					CFArrayRef			changedKeys,
					void				*info
					)
{
	if (verbosity >= 3)
	{
		CFShow(CFSTR("Restarting daemon because of the following changes in the dynamic store:"));
		CFIndex cnt = CFArrayGetCount(changedKeys);
		CFIndex i;
		for (i = 0; i < cnt; ++i)
		{
			CFStringRef value = CFArrayGetValueAtIndex(changedKeys, i);
			CFShow(value);
		}
	}
	
	ScheduleDelayedRestart();
}


void
PowerCallBack(void *x, io_service_t y, natural_t messageType, void *messageArgument)
{
    switch (messageType)
	{
	case kIOMessageSystemWillSleep:
	case kIOMessageCanSystemSleep:
		/*  Power Manager waits for your reply via one of these functions for up
		to 30 seconds. If you don't acknowledge the power change by calling
		IOAllowPowerChange(), you'll delay sleep by 30 seconds. */
		IOAllowPowerChange(pwrRootPort, (long)messageArgument);
		break;
	case kIOMessageSystemHasPoweredOn:
		if (restartOnWakeup)
		{
			if (verbosity >= 3)
				printf("Restarting daemon because of system wake from sleep\n");
			ScheduleDelayedRestart();
		}
		break;
    }
}


void
NotificationCenterCallback(
								CFNotificationCenterRef center, 
								void *observer, 
								CFStringRef name, 
								const void *object, 
								CFDictionaryRef userInfo)
{
	if (verbosity >= 3)
	{
		CFShow(CFSTR("Restarting daemon due to receipt of the following notification:"));
		CFShow(name);
	}
		
	ScheduleDelayedRestart();
}


void
SignalCallback(CFMachPortRef port, void *msg, CFIndex size, void *info)
{
	mach_msg_header_t* hdr = (mach_msg_header_t*)msg;
	switch (hdr->msgh_id)
	{
	case SIGTERM:		
		// On receipt of SIGTERM we set our terminate flag and stop the process
		if (!terminating)
		{
			terminating = true;
			Stop();
		}
		break;
	
	case SIGHUP:
		if (!terminating)
			Restart();
		break;
		
	case SIGCHLD:
		CheckChildren();
		break;
		
	default:
		break;
	}
}


void
AddNotificationToCenter(const void* value, void* context)
{
	CFNotificationCenterAddObserver((CFNotificationCenterRef)context,
		kProgramName,
		NotificationCenterCallback,
		value,		// name of notification
		NULL,		// object to observe
		CFNotificationSuspensionBehaviorDeliverImmediately);
}


void handle_child_signal(int sig)
{
	// Because there's a limited environment in which we can operate while
	// handling a signal, we send a mach message to our run loop, and handle
	// things from there.
	mach_msg_header_t header;
	header.msgh_bits		= MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
	header.msgh_size		= sizeof(header);
	header.msgh_remote_port	= sigChild_m_port;
	header.msgh_local_port	= MACH_PORT_NULL;
	header.msgh_reserved	= 0;
	header.msgh_id			= sig;
	
	mach_msg_return_t status = mach_msg_send(&header);
	status = 0;
}


void handle_generic_signal(int sig)
{
	// Because there's a limited environment in which we can operate while
	// handling a signal, we send a mach message to our run loop, and handle
	// things from there.
	mach_msg_header_t header;
	header.msgh_bits		= MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
	header.msgh_size		= sizeof(header);
	header.msgh_remote_port	= sigGeneric_m_port;
	header.msgh_local_port	= MACH_PORT_NULL;
	header.msgh_reserved	= 0;
	header.msgh_id			= sig;
	
	mach_msg_return_t status = mach_msg_send(&header);
	status = 0;
}


int
MainLoop(void)
{
	// *** TODO: This routine needs more error checking
	
	int status = 0;
	
	
	// === Setup Notifications of Changes to System Configuration ===
	// Create a new SCDynamicStore session and an associated runloop source, adding it default mode
	SCDynamicStoreRef	dsRef			= SCDynamicStoreCreate(NULL, kProgramName, DynamicStoreChanged, NULL);
	CFRunLoopSourceRef	dsSrc			= SCDynamicStoreCreateRunLoopSource(NULL, dsRef, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), dsSrc, kCFRunLoopDefaultMode);
	
	// Tell the DynamicStore which keys to notify us on: this is the set of keys on which the
	// daemon will be restarted, at least for now--we may want to give more flexibility at some point.
	(void) SCDynamicStoreSetNotificationKeys(dsRef, NULL, scRestartPatterns);
	
	
	// === Setup Notifications from Notification Centers  ===
	CFArrayApplyFunction(distNotifyNames, CFRangeMake(0, CFArrayGetCount(distNotifyNames)),
		AddNotificationToCenter, CFNotificationCenterGetDistributedCenter());
	CFArrayApplyFunction(darwinNotifyNames, CFRangeMake(0, CFArrayGetCount(darwinNotifyNames)),
		AddNotificationToCenter, CFNotificationCenterGetDarwinNotifyCenter());


	// === Setup Notifications of Changes to System Power State ===
	// Register for system power notifications, adding a runloop source to handle then
	IONotificationPortRef	powerRef = NULL;
    io_object_t				pwrNotifier = 0;
    pwrRootPort = IORegisterForSystemPower(0, &powerRef, PowerCallBack, &pwrNotifier);
    if (pwrRootPort != 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(powerRef), kCFRunLoopDefaultMode);
		
	
	// === Setup Notifications of Signals ===
	// Add a mach port source to our runloop for handling of the signals
	CFMachPortRef		sigChildPort	= CFMachPortCreate(NULL, SignalCallback, NULL, NULL);
	CFMachPortRef		sigGenericPort	= CFMachPortCreate(NULL, SignalCallback, NULL, NULL);
	
	CFRunLoopSourceRef	sigChildSrc		= CFMachPortCreateRunLoopSource(NULL, sigChildPort, 0);
	CFRunLoopSourceRef	sigGenericSrc	= CFMachPortCreateRunLoopSource(NULL, sigGenericPort, 0);
	
	// Add only the child signal source to the childwatch mode
	CFRunLoopAddSource(CFRunLoopGetCurrent(), sigChildSrc, kChildWatchMode);

	// Add both child and generic signal sources to the default mode
	CFRunLoopAddSource(CFRunLoopGetCurrent(), sigChildSrc, kCFRunLoopDefaultMode);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), sigGenericSrc, kCFRunLoopDefaultMode);
	
	// Install signal handlers
	sigChild_m_port		= CFMachPortGetPort(sigChildPort);
	sigGeneric_m_port	= CFMachPortGetPort(sigGenericPort);

	signal(SIGCHLD, handle_child_signal);
	signal(SIGTERM, handle_generic_signal);
	signal(SIGHUP, handle_generic_signal);
	
	
	// === Core Loop ===
	// Start the daemon
	status = Start();
	
	// Run the run loop until we stop it, or until the process we're tracking stops
	while (status == 0 && !terminating && runningPid != 0)
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 99999999.0, true);
		
		
	// === Tear Down ==
	// The daemon should by now have either been stopped, or stopped of its own accord
		
	// Remove signal handlers
	signal(SIGTERM, SIG_DFL);
	signal(SIGHUP, SIG_DFL);
	signal(SIGCHLD, SIG_DFL);
	
	sigChild_m_port = 0;
	sigGeneric_m_port = 0;
	
	// Tear down signal handling infrastructure
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), sigChildSrc, kChildWatchMode);
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), sigChildSrc, kCFRunLoopDefaultMode);
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), sigGenericSrc, kCFRunLoopDefaultMode);
	
	CFRelease(sigChildSrc);
	CFRelease(sigGenericSrc);
	
	CFRelease(sigChildPort);
	CFRelease(sigGenericPort);

	// Tear down DynamicStore stuff
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), dsSrc, kCFRunLoopDefaultMode);
	
	CFRelease(dsSrc);
	CFRelease(dsRef);
	
	// Tear down notifications from Notification Center
	CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDistributedCenter(), kProgramName);
	CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), kProgramName);

	// Tear down power management stuff
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(powerRef), kCFRunLoopDefaultMode);
	IODeregisterForSystemPower(&pwrNotifier);
	
	return status;	
}


int
CollectCmdArgs(char* arg1, int argc, char* const argv[], const char * const ** args)
{
	// Count the number of additional arguments up until end of args or the marker argument ";"
	int moreArgs = 0;
	for (; moreArgs < argc && 0 != strcmp(";", argv[moreArgs]); ++moreArgs)
		;
		
	// We were given one argument for free
	int nargs = moreArgs + 1;
		
	// Allocate an array for the arguments
	*args = calloc(sizeof(char**), nargs+1);
	if (!*args)
		return 0;
		
	// Copy the arguments into our new array
	(*(char***)args)[0] = arg1;
	
	int i;
	for (i = 0; i < moreArgs; ++i)
		(*(char***)args)[i+1] = argv[i];
		
	// NULL-terminate the argument array
	(*(char***)args)[nargs] = NULL;
	
	// Return number of args we consumed, accounting for potential trailing ";"
	return (moreArgs == argc) ? moreArgs : moreArgs + 1;
}


void
AddSingleArrayArg(const char* arg, CFMutableArrayRef array)
{
	CFStringRef s = CFStringCreateWithCString(NULL, arg, kCFStringEncodingUTF8);
	CFArrayAppendValue(array, s);
	CFRelease(s);
}


int
CollectArrayArgs(char* arg1, int argc, char* const argv[], CFMutableArrayRef array)
{
	// Let CollectCmdArgs do the grunt work
	const char* const* args	= NULL;
	int argsUsed = CollectCmdArgs(arg1, argc, argv, &args);
	
	// Add arguments to the mutable array
	if (args != NULL)
	{
		const char* const* argp = args;
		for (; *argp != NULL; ++argp)
			AddSingleArrayArg(*argp, array);
		free((void*)args);
	}
	
	return argsUsed;
}


enum {
	kVerbosityOpt			= 256,
	kRestartConfigOpt,
	kRestartDistNotifyOpt,
	kRestartDarwinNotifyOpt,
	kRestartWakeupOpt,
	kRestartNetChangeOpt,
	kPidOpt,
	kPidFileOpt
};


int
main(int argc, char* argv[])
{
	int status = 0;
	
	// Initialization
	kProgramName		= CFSTR("daemondo");
	kChildWatchMode		= CFSTR("ChildWatch");
	
	scRestartPatterns	= CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	distNotifyNames		= CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	darwinNotifyNames	= CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	
	// Make stdout flush after every line
	setvbuf(stdout, (char *)NULL, _IOLBF, 0);
	
	// Process arguments
	static struct option longopts[] = {
			// Start/Stop/Restart the process
		{ "start-cmd",		required_argument,		0,				's' },
		{ "stop-cmd",		required_argument,		0,				'k' },
		{ "restart-cmd",	required_argument,		0,				'r' },
		
			// Dynamic Store Keys to monitor
		{ "restart-config",	required_argument,		0,				kRestartConfigOpt },
		
			// Notifications to monitor
		{ "restart-dist-notify",
							required_argument,		0,				kRestartDistNotifyOpt },
		{ "restart-darwin-notify",
							required_argument,		0,				kRestartDarwinNotifyOpt },
		
			// Control over behavior on power state
		{ "restart-wakeup",	no_argument,			0,				kRestartWakeupOpt },

			// Short-cuts
		{ "restart-netchange",
							no_argument,			0,				kRestartNetChangeOpt },
							
			// Pid-files
		{ "pid",			required_argument,		0,				kPidOpt },
		{ "pidfile",		required_argument,		0,				kPidFileOpt },
		
			// other
		{ "help",			no_argument,			0,				'h' },
		{ "v",				no_argument,			0,				'v' },
		{ "verbosity",		optional_argument,		0,				kVerbosityOpt },
		{ "version",		no_argument,			0,				'V' },
		{ "label",			required_argument,		0,				'l' },
		
		{ 0,				0,                      0,              0 }
	};

	while (status == 0 && optind < argc)
	{
		int optindex = 0;
		int ret = getopt_long(argc, argv, ":s:k:r:l:hvV", longopts, &optindex);
		int opt = (ret == '?') ? optopt : ret;
		switch (opt)
		{
		case ':':
			printf("Option error: missing argument for option %s\n", longopts[optindex].name);
			exit(1);
			break;
			
		case 's':
			if (startArgs)
			{
				printf("Option error: start-cmd option may be given only once.\n");
				exit(1);
			}
			else
			{
				optind += CollectCmdArgs(optarg, argc - optind, argv + optind, &startArgs);
				optreset = 1;
			}
			break;
			
		case 'k':
			if (stopArgs)
			{
				printf("Option error: stop-cmd option may be given only once.\n");
				exit(1);
			}
			else
			{
				optind += CollectCmdArgs(optarg, argc - optind, argv + optind, &stopArgs);
				optreset = 1;
			}
			break;

		case 'r':
			if (restartArgs)
			{
				printf("Option error: restart-cmd option may be given only once.\n");
				exit(1);
			}
			else
			{
				optind += CollectCmdArgs(optarg, argc - optind, argv + optind, &restartArgs);
				optreset = 1;
			}
			break;
			
		case kRestartConfigOpt:
			optind += CollectArrayArgs(optarg, argc - optind, argv + optind, scRestartPatterns);
			optreset = 1;
			break;
			
		case kRestartDistNotifyOpt:
			optind += CollectArrayArgs(optarg, argc - optind, argv + optind, distNotifyNames);
			optreset = 1;
			break;
			
		case kRestartDarwinNotifyOpt:
			optind += CollectArrayArgs(optarg, argc - optind, argv + optind, darwinNotifyNames);
			optreset = 1;
			break;
			
		case kRestartWakeupOpt:
			restartOnWakeup = TRUE;
			break;
			
		case kRestartNetChangeOpt:
			AddSingleArrayArg("com.apple.system.config.network_change", darwinNotifyNames);
			break;
			
		case kPidOpt:
			if      (0 == strcasecmp(optarg, "none"))
				pidStyle = kPidStyleNone;
			else if (0 == strcasecmp(optarg, "exec"))
				pidStyle = kPidStyleExec;
			else if (0 == strcasecmp(optarg, "fileauto"))
				pidStyle = kPidStyleFileAuto;
			else if (0 == strcasecmp(optarg, "fileclean"))
				pidStyle = kPidStyleFileClean;
			break;
		
		case kPidFileOpt:
			if (pidFile != NULL)
				free((char*)pidFile);
			pidFile = strdup(optarg);
			break;
		
		case 'h':
			DoHelp();
			exit(0);
			break;
			
		case 'l':
			if (label != NULL)
				free((char*)label);
			label = strdup(optarg);
			break;
			
		case 'v':
			++verbosity;
			break;
		
		case kVerbosityOpt:
			if (optarg)
				verbosity = atoi(optarg);
			else
				++verbosity;
			break;
	
		case 'V':
			DoVersion();
			break;
		}
	}
	
	// Default the pid style if it wasn't given
	if (pidStyle == kPidStyleUnknown)
	{
		if (startArgs && !stopArgs && !restartArgs)
			pidStyle = kPidStyleExec;
		else
			pidStyle = kPidStyleNone;
	}
	
	// Go into our main loop
	if (status == 0 && startArgs)
		status = MainLoop();
	else
		DoHelp();
		
    return status;
}
