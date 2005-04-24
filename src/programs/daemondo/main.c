/*
	daemondo - main.c
	
	Copyright (c) 2005 James Berry <jberry@opendarwin.org>
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

	$Id: main.c,v 1.2 2005/04/24 01:02:33 jberry Exp $
*/
	
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <getopt.h>
#include <fcntl.h>
#include <mach/mach.h>

#include <CoreFoundation/CoreFoundation.h>

// Globals
CFStringRef kChildWatchMode		= NULL;

int verbosity	= 0;							// Verbosity level

const char* const* startArgs	= NULL;			// Argvs for start-cmd, stop-cmd, and restart-cmd
const char* const* stopArgs		= NULL;
const char* const* restartArgs	= NULL;

int				terminating			= 0;		// True if we're terminating
int				start_async			= 0;		// True if we are running start-cmd asyncronously
pid_t			running_pid			= 0;		// Process id from start_cmd

mach_port_t		sigChild_m_port		= 0;		// Mach port to send signals through
mach_port_t		sigGeneric_m_port	= 0;		// Mach port to send signals through


void
DoVersion(void)
{
	printf("daemondo, version 1.0d1\n\n");
}


void
DoHelp(void)
{
	DoVersion();
	
	const char* helpText =
		"usage: daemondo [-hv] --start-cmd prog args... ;\n"
		"                     [--stop-cmd prog arg... ;]\n"
		"                     [--restart-cmd prog arg... ;]\n"
		"                     [--version]\n"
		"\n"
		"daemondo is a wrapper program that runs daemons. It starts the specified\n"
		"daemon on launch, stops it when given SIGTERM, and restarts it on SIGHUP.\n"
		"\n"
		"daemondo may be further extended in the future restart daemons on certain\n"
		"other events such as changes in network availability and/or power transitions.\n"
		"\n"
		"  -h, --help                  Provide this help.\n"
		"  -v                          Increase verbosity.\n"
		"  --verbose=n                 Set verbosity to n.\n"
		"  --version                   Display program version information.\n"
		"\n"
		"  -s, --start-cmd args... ;   Required: command that will start the daemon.\n"
		"  -k, --start-cmd args... ;   The command that will stop the daemon.\n"
		"  -r, --restart-cmd args... ; The command that will restart the daemon.\n"
		"\n"
		"daemondo responds to SIGHUP by restarting the daemon, and to SIGTERM by\n"
		"stopping it. daemondo exits on receipt of SIGTERM, or when the deamon dies.\n"
		"\n"
		"The arguments start-cmd, stop-cmd, and restart-cmd, if present, must each be\n"
		"followed by a command and arguments, and terminated by a ';'. You may need to\n"
		"espace or quote the ';' to protect it from special handling by your shell.\n"
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
		"In mode 1 only, daemondo will exit when it detects that the daemon being\n"
		"monitored has exited.\n"
		"\n"
		;
		
	printf(helpText);
}


void
WaitChildDeath(pid_t childPid)
{
	// Wait for the death of a particular child
	int wait_result = 0;
	int wait_stat = 0;
	
	// Set up a timer for how long we'll wait for child death before we
	// kill the child outright
	double kChildTimeout = 20.0;
	CFAbsoluteTime patience = CFAbsoluteTimeGetCurrent() + kChildTimeout;
	
	// Wait for the death of child, calling into our run loop if it's not dead yet
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
			if (verbosity >= 2)
				printf("Child %d didn't die; Killing with SIGKILL.\n", childPid);
			kill(childPid, SIGKILL);
		}
	}
	
	// The child should be dead and gone by now.
}


void
CheckChildren(void)
{
	// Process any pending child deaths
	int wait_stat = 0;
	pid_t pid = 0;
	while ((pid = wait4(0, &wait_stat, WNOHANG, NULL)) != 0 && pid != -1)
	{
		// Take special note if process running_pid dies
		if (pid == running_pid)
		{
			if (verbosity >= 2)
				printf("Running process %d died.\n", pid);
			running_pid = 0;
			CFRunLoopStop(CFRunLoopGetCurrent());
		}
	}
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
			// If synchronous, wait for the process to complete
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
		if (verbosity >= 0)
			fprintf(stderr, "There is nothing to start. No start-cmd was specified.\n");
		return 2;
	}
	
	if (verbosity >= 1)
		printf("Running start-cmd %s.\n", startArgs[0]);
	pid_t pid = Exec(startArgs, !start_async);
	if (pid == -1)
	{
		if (verbosity >= 1)
			fprintf(stderr, "Error running start-cmd %s.\n", startArgs[0]);
		return 2;
	}
	
	if (pid)
	{
		if (verbosity >= 1)
			printf("Started process id %d\n", pid);
		running_pid = pid;
	}
	
	return 0;
}


int
Stop(void)
{
	if (!stopArgs || !stopArgs[0])
	{
		// We don't have a stop command, so we try to kill any process
		// we've tracked with running_pid
		if (running_pid)
		{
			if (verbosity >= 1)
				printf("Stopping pid %d...\n", running_pid);
			
			// Send the process a SIGTERM to ask it to quit
			kill(running_pid, SIGTERM);
			
			// Wait for process to quit, killing it after a timeout
			WaitChildDeath(running_pid);
			
			if (verbosity >= 1)
				printf("Process stopped.\n");
		}
		else
		{
			if (verbosity >= 1)
				printf("Process already stopped.\n");
		}
	}
	else
	{
		// We have a stop-cmd to use. We execute it synchronously,
		// and trust it to do the job.
		if (verbosity >= 1)
			printf("Running stop-cmd %s.\n", stopArgs[0]);
		pid_t pid = Exec(stopArgs, TRUE);
		if (pid == -1)
		{
			if (verbosity >= 1)
				printf("Error running stop-cmd %s\n", stopArgs[0]);
			return 2;
		}
	}

	return 0;
}


int
Restart(void)
{
	if (!restartArgs || !restartArgs[0])
	{
		Stop();
		Start();
	}
	else
	{
		if (verbosity >= 1)
			printf("Running restart-cmd %s.\n", restartArgs[0]);
		pid_t pid = Exec(restartArgs, TRUE);
		if (pid == -1)
		{
			if (verbosity >= 1)
				printf("Error running restart-cmd %s\n", restartArgs[0]);
			return 2;
		}
	}
	
	return 0;
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
	int status = 0;
	
	// Initialize mode names
	kChildWatchMode	= CFSTR("ChildWatch");

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
	
	// Start the daemon
	status = Start();
	
	// Run the run loop until we stop it, or until the process we're tracking stop
	while (status == 0 && !terminating && !(start_async && running_pid == 0))
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 99999999.0, true);
		
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

	return status;	
}


int
CollectCmdArgs(int argc, char* const argv[], const char * const ** args)
{
	// Count the number of arguments up until end of args or the marker argument ";"
	int nargs = 0;
	for (; nargs < argc && 0 != strcmp(";", argv[nargs]); ++nargs)
		;
		
	// Don't generate a zero-length cmd vector
	*args = NULL;
	if (!nargs)
		return 0;
		
	// Allocate an array for the arguments
	*args = calloc(sizeof(char**), nargs+1);
	if (!*args)
		return 0;
		
	// Copy the arguments into our new array
	int i;
	for (i = 0; i < nargs; ++i)
		(*(char***)args)[i] = argv[i];
		
	// NULL-terminate the argument array
	(*(char***)args)[nargs] = NULL;
	
	return (nargs == argc) ? nargs : nargs + 1;
}


enum {
	kVerboseOpt		= 256
};


int
main(int argc, char* argv[])
{
	int status = 0;

	//	Process arguments
	static struct option longopts[] = {
			// Start/Stop/Restart the process
		{ "start-cmd",		no_argument,			0,				's' },
		{ "stop-cmd",		no_argument,			0,				'k' },
		{ "restart-cmd",	no_argument,			0,				'r' },

			// other
		{ "help",			no_argument,			0,				'h' },
		{ "v",				no_argument,			0,				'v' },
		{ "verbose",		required_argument,		0,				kVerboseOpt },
		{ "version",		no_argument,			0,				'V' },
		
		{ 0,				0,                      0,              0 }
	};

	while (status == 0 && optind < argc)
	{
		int optindex = 0;
		int ret = getopt_long(argc, argv, "skrhv", longopts, &optindex);
		int opt = (ret == '?') ? optopt : ret;
		switch (opt)
		{
		case 's':
			if (startArgs)
			{
				printf("Option error: start-cmd option may be given only once.\n");
				exit(1);
			}
			else
			{
				optind += CollectCmdArgs(argc - optind, argv + optind, &startArgs);
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
				optind += CollectCmdArgs(argc - optind, argv + optind, &stopArgs);
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
				optind += CollectCmdArgs(argc - optind, argv + optind, &restartArgs);
				optreset = 1;
			}
			break;
		
		case 'h':
			DoHelp();
			exit(0);
			break;
			
		case 'v':
			++verbosity;
			break;
		
		case kVerboseOpt:
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
	
	// Decide whether we'll be syncronous or not
	start_async = (startArgs && !stopArgs && !restartArgs);
	
	// Go into our main loop
	if (status == 0 && startArgs)
		status = MainLoop();
	else
		DoHelp();
		
    return status;
}
