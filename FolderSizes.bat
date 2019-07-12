@TITLE Folder_Sizes
@echo off
setlocal EnableDelayedExpansion

REM Note: The old (pre windows 10) command line could not backspace up lines.
REM The new one appears to be able to, screwing up the output if one attempts
REM to just backspace as much as possible until the start of the line is reached.
REM Instead, the number of backspaces needed is specified exactly.

:###############################################################---Setup---######################################################

ECHO(
<nul set /p "var=:::Starting Up . . ."


:#Initial Setup
	REM Get parameters, %CD%, unpack, go to manual mode, get settings, detect errors, etc.
	
	if NOT EXIST "%~dp0" CALL :InstallDirError
	
	if NOT EXIST "%~dp0\hasUnpacked.txt" CALL :UNPACK
	
	REM Loads the settings from the files in the settings folder
	SET /p setting_shortenOutput=<"%~dp0\Settings\setting_shortenOutput.txt"
	SET /p setting_showEllipsis=<"%~dp0\Settings\setting_showEllipsis.txt"
	SET /p setting_lnkPathType=<"%~dp0\Settings\setting_lnkPathType.txt"
	
	REM Removes quotes from parameters, and stores then in a manipulatable variable (changed in manual mode)
	SET "param1=%~1"
	SET "param2=%~2"
	REM sets the directory that the program started in (or manual mode set it to start in)
	SET origCD=!CD!
	
	REM detects ! or other characters
	if DEFINED param1 if NOT EXIST "%param1%" ECHO ERROR(1): Problematic characters detected. & PAUSE>nul & SET ERROR1=True
	if NOT EXIST "%origCD%" ECHO ERROR(2): Problematic characters detected. & PAUSE>nul & SET ERROR2=True
	REM param2 does not matter, as it is only used as a boolean (DEFINED/NOT)
REM



:#Backspace Setup
	REM Stores backspace characters in various variables. Used along with: <nul set "var=some text to echo"
	REM ...in order to echo text without a linefeed (LF). This text can then be backspaced using the BS character 
	REM (acts like a left arrow key - moves the cursor but doesn't erase the text) overwritten with spaces, and
	REM then something else can be echoed.
	CALL :GetChr "chr(8)"
	SET "BS=%result%
	SET "BS10=%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%"
	REM SET "BSln=%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%%BS%"
	REM SET "BSln=%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%%BS10%"
	REM SET "ClrLn=%BSln%                                                                               %BSln%"
	REM SET "ClrLn=%BSln%                                                                                                                                                                                          %BSln%"
	SET "Clr10=%BS10%          %BS10%"
	SET "Clr1=%BS% %BS%"
REM

:#Initial Setup Part 2
	REM Clear "Starting up" text before possibly entering manual mode
	<nul set /p "var=!Clr10!!Clr10!"
	
	REM Calls ManualMode if no folders/files have been dragged onto the Folder Sizes program (it was opened by double clicking)
	if NOT DEFINED param1 CALL :ManualMode
REM


:#WORKING_DIRECTORY Setup
	
	REM Sets WORKING_DIRECTORY to the correct directory depending on whether 1 or 2 files were dragged onto the Folder Sizes program.
	if DEFINED param2 (
		SET WORKING_DIRECTORY=!origCD!
	) else (
		if EXIST "!param1!\" (
			SET WORKING_DIRECTORY=!param1!
		) else (
			if EXIST "!param1!" (
				if !param1:~-4!==.lnk (
					SET WORKING_DIRECTORY=!param1!
				) else (
					SET WORKING_DIRECTORY=!origCD!
				)
			) else (
				ECHO ERROR^(3^): Problematic characters detected. & PAUSE>nul & SET ERROR3=True
			)
		)
	)
	
	REM If WORKING_DIRECTORY points to a .lnk file, call ParseLnk to CD into the correct path. ParseLnk then sets WORKING_DIRECTORY to this new %CD%
	if /I !WORKING_DIRECTORY:~-4!==.lnk (
		CALL :ParseLnk
	)
	
	SET mainCD="!WORKING_DIRECTORY!"
REM



:#Log File Setup
	REM gets the current date and time in an appropriate format, using 'wmic'.
	for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set rawDateTime=%%I
	SET "dateTime=!rawDateTime:~0,4!-!rawDateTime:~4,2!-!rawDateTime:~6,2!@!rawDateTime:~8,2!-!rawDateTime:~10,2!-!rawDateTime:~12,2!"
	
	REM Builds a filename for the current log file.
	CALL :GetSingleFolder "!WORKING_DIRECTORY!"
	CALL :ShortenVar singleFolder 40
	SET "percentDP0=%~dp0"
	SET "logFile=!percentDP0!Previous Folders\'!shortened!'[!dateTime!].html"
	
	REM Creates the file and sets the styling for the html document.
	ECHO ^<style^>^*{font-family:"Lucida Console",Monaco,monospace;}^</style^> >"!logFile!"
	
	REM Sends errors to the file which it could not send before (the errors occur before
	REM %WORKING_DIRECTORY% is set, and the filename contains %WORKING_DIRECTORY%)
	if "%ERROR1%"=="True" ECHO ERROR(1): Problematic characters detected.^<br^> >>"!logFile!"
	if "%ERROR2%"=="True" ECHO ERROR(2): Problematic characters detected.^<br^> >>"!logFile!"
	if "%ERROR3%"=="True" ECHO ERROR(3): Problematic characters detected.^<br^> >>"!logFile!"
REM



:#Set Booleans
	SET areThereFolders=False
	SET areThereLnks=False
	SET showOutput=True
REM



:###############################################################---Main-Loops---######################################################

:#Title
	REM Clear the line (get rid of Starting Up . . .), and echo WORKING_DIRECTORY. Also send this into
	REM the log-file. Follow this by a horizontal line (****...**** or <hr>)
	ECHO !WORKING_DIRECTORY!
	ECHO !WORKING_DIRECTORY!^<br^> >>"!logFile!"
	ECHO *******************************************************************************
	ECHO ^<hr^> >>"!logFile!"
REM

:#Folders
	REM echo something that means please wait.
	REM loop through all the folders in WORKING_DIRECTORY, calling :FuncInFor for each one.
	<nul set /p "var=:::Finding folders to list . . ."
	for /f "usebackq delims=" %%g in (`DIR "!WORKING_DIRECTORY!" /A:D /D /B`) do ( SET "varFromFor=%%g" & CALL :GetFolderSize )
	
	REM Check if FuncInFor was ever actually entered, and if not say there are no folders. Otherwise, echo a blank line.
	if %areThereFolders%==False ( ECHO There are no folders to list. & ECHO There are no folders to list^<br^> >>"!logFile!" ) else ( ECHO: & ECHO ^<br^> >>"!logFile!" )
	ECHO *******************************************************************************
	ECHO ^<hr^> >>"!logFile!"
REM

:#Shortcuts
	REM Set/change/reset some boolean variables.
	SET areThereFolders=False
	
	REM do the same as the previous for loop (above), but this time with *.lnk files instead of folders.
	<nul set /p "var=:::Finding shortcuts to list . . ."
	for /f "usebackq delims=" %%g in (`DIR "!WORKING_DIRECTORY!\*.lnk" /D /B 2^>nul`) do ( SET "varFromFor=%%g" &  CALL :GetShortcutSize )
	
	REM Check if ParseLnkToMeasure was ever entered and was sucessful, and if not say there are no shortcuts. Otherwise, echo a blank line.
	if %areThereLnks%==False (
		ECHO !Clr10!!Clr10!!Clr10!!Clr1!!Clr1!!Clr1!!Clr1!There are no folder-shortcuts to list. & ECHO There are no folder-shortcuts to list.^<br^> >>"!logFile!"
	) else (
		ECHO: & ECHO ^<br^> >>"!logFile!"
	)
	
	ECHO *******************************************************************************
	ECHO ^<hr^> >>"!logFile!"
REM

ECHO ^<p style="font-size:12px"^>^&nbsp;~ By Alex17319^</p^> >>"!logFile!"
<nul set /p "var=Press any key to exit . . . " & PAUSE>nul & ECHO !Clr10!!Clr10!!Clr10!!Clr1!!Clr1!
GOTO :END


:###############################################################---Loop-Functions---######################################################

:GetFolderSize
	ECHO !Clr10!!Clr10!!Clr10!!Clr1!!Clr1!
	
	REM Detects ! or other characters
	if NOT EXIST "!WORKING_DIRECTORY!\%varFromFor%" ECHO ERROR(4): Problematic characters detected. & PAUSE>nul & ECHO ERROR(4): Problematic characters detected. ^<br^> >>"!logFile!"
	
	REM Echo blank lines correctly
	if %areThereFolders%==False SET areThereFolders=True & ECHO( & ECHO ^<br^> >>"!logFile!" & ECHO ^<br^> >>"!logFile!"
	
	:#Echo What The Current Item Is
		REM Shorten the name of the folder (if necessary), and then echo it.
		CALL :ShortenVar varFromFor 76
		ECHO  - !shortened!
		ECHO ^&nbsp;- !varFromFor!^<br^> >>"!logFile!"
	REM
	
	:#Calculate The Size
		<nul set /p "var=:::Calculating the folder size . . ."
		
		SET currentPos=0
		SET dirResult=FOO
		REM Execute a recurring DIR command on the current folder, and get the second to last line of it, which contains the size.
		for /F "usebackq delims=" %%i in (`DIR "!WORKING_DIRECTORY!"\"!varFromFor!" /A:-D /S 2^>nul`) do (
			SET /a currentPos+=1
			SET "prevDirResult=!dirResult!"
			SET "dirResult=%%i"
		)
	REM
	
	:#Echo The Size
		REM Echo the results of the above section.
		if %currentPos%==2 (
			ECHO !Clr10!!Clr10!!Clr10!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!                 The folder and subfolders contain no files & ECHO ^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;The folder and subfolders contain no files^<br^> >>"!logFile!"
		) else (
			ECHO !Clr10!!Clr10!!Clr10!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!   !prevDirResult! & ECHO ^&nbsp;^&nbsp;^&nbsp;!prevDirResult: =^&nbsp;!^<br^> >>"!logFile!"
		)
		ECHO( & ECHO ^<br^> >>"!logFile!"
	REM
	
	GOTO :eof
REM

:GetShortcutSize
	ECHO !Clr10!!Clr10!!Clr10!!Clr1!!Clr1!!Clr1!!Clr1!
	
	REM Detects ! or other characters
	if NOT EXIST "!WORKING_DIRECTORY!\%varFromFor%" ECHO ERROR(5): Problematic characters detected. & PAUSE>nul & ECHO ERROR(5): Problematic characters detected. ^<br^> >>"!logFile!"
	
	REM <nul set /p "var=!BSln!:::Finding next folder-shortcut . . ."
	<nul set /p "var=:::Finding next folder-shortcut . . ."
	
	REM Set showOutput to false. ParseLnkToMeasure will change this to true if the shortcut points to a folder.
	REM The name of the current item, and it's size, will only be displayed if showOutput is true (i.e. if the item is valid)
	REM ParseLnkToMeasure also clears the line
	SET showOutput=False
	CALL :ParseLnkToMeasure
	
	if %showOutput%==True  CALL :ShowTheOutput
	GOTO :eof
	
	:ShowTheOutput
		:#Echo What The Current Item Is
			REM Shorten the name of the shortcut (if necessary), and then echo it.
			CALL :ShortenVar varFromFor 76
			ECHO  - !shortened!
			ECHO ^&nbsp;- !varFromFor!^<br^> >>"!logFile!"
			
			REM Echo where the shortcut points to. Echo different things (path/name/nothing) depending on the user's settings.
			if "!setting_lnkPathType!"=="PATHS" CALL :ShortenVar LNK_WORKING_DIRECTORY 74
			if "!setting_lnkPathType!"=="NAMES" (
				CALL :GetSingleFolder "!LNK_WORKING_DIRECTORY!"
				CALL :ShortenVar singleFolder 74
			)
			if NOT "!setting_lnkPathType!"=="NONE" ECHO    = !shortened!
			ECHO ^<font color="#b0b0b0"^>^&nbsp;^&nbsp;^&nbsp;= !LNK_WORKING_DIRECTORY!^</font^>^<br^> >>"!logFile!"
		REM
		
		:#Calculate The Size
			<nul set /p "var=:::Calculating the folder size . . ."
			
			SET currentPos=0
			SET dirResult=FOO
			
			REM Execute a recurring DIR command on the current folder, and get the second to last line of it, which contains the size.
			for /F "usebackq delims=" %%i in (`DIR "!LNK_WORKING_DIRECTORY!" /A:-D /S 2^>nul`) do (
				SET /a currentPos+=1
				SET "prevDirResult=!dirResult!"
				SET "dirResult=%%i"
			)
		REM
	
		:#Echo The Size
			REM Echo the results of the above section.
			<nul set /p "var=!Clr10!!Clr10!!Clr10!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!"
			if %currentPos%==2 (
				ECHO                 The folder and subfolders contain no files & ECHO ^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;^&nbsp;The folder and subfolders contain no files^<br^> >>"!logFile!"
			) else (
				ECHO    !prevDirResult! & ECHO ^&nbsp;^&nbsp;^&nbsp;!prevDirResult: =^&nbsp;!^<br^> >>"!logFile!"
			)
			ECHO: & ECHO ^<br^> >>"!logFile!"
		REM
		GOTO :eof
	REM
REM

:###############################################################---Other-Functions---######################################################

:ParseLnk
	REM Send the shortcut location to a vbscript file, which returns where the shortcut points to.
	for /f "delims=" %%d in ('cscript //nologo "%~dp0\ParseShortcut.vbs"  "!WORKING_DIRECTORY!"') do CD /d "%%d" 2>nul
	
	REM Detects ! or other characters
	if NOT EXIST "%CD%" ECHO ERROR(6): Problematic characters detected. & PAUSE>nul & ECHO ERROR(6): Problematic characters detected. ^<br^> >>"!logFile!"
	
	SET WORKING_DIRECTORY=!CD!
	GOTO :eof
REM


:ParseLnkToMeasure
	CD %mainCD%
	
	REM Send the shortcut location to a vbscript file, which returns where the shortcut points to.
	for /f "delims=" %%d in ('cscript //nologo "%~dp0\ParseShortcut.vbs" "!varFromFor!" 2^>nul') do ( CD /d "%%d" 2>nul )
	
	REM Echo blank line correctly
	<nul set /p "var=!Clr10!!Clr10!!Clr10!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!!Clr1!"
	
	REM Detects ! or other characters
	if NOT EXIST "%CD%" ECHO ERROR(7): Problematic characters detected. & PAUSE>nul & ECHO ERROR(7): Problematic characters detected. ^<br^> >>"!logFile!"
	
	SET "LNK_WORKING_DIRECTORY=!CD!"
	
	REM If the shortcut points to a folder (not a file), the variable %CD% will have changed from being %mainCD%.
	if /I NOT !mainCD!=="!CD!" (
		SET showOutput=True
		SET areThereLnks=True
		REM Echo blank line correctly
		if %areThereFolders%==False ECHO: & SET areThereFolders==True & ECHO ^<br^> >>"!logFile!" & ECHO ^<br^> >>"!logFile!"
	)
	
	GOTO :eof
REM

:GetChr
	REM The following is adapted from <http://superuser.com/a/479051>:
	
	REM 				-- evaluate with VBS and return to result variable
	REM 				-- %~1: VBS string to evaluate
	REM extra info: http://groups.google.com/group/alt.msdos.batch.nt/browse_thread/thread/9092aad97cd0f917
	
	if "[%1]"=="[]" ECHO Input argument missing & GOTO :EOF 
	ECHO wsh.echo "result="^&eval("%~1") > "%~dp0\evaluate_tmp_67354.vbs"
	for /f "delims=" %%a in ('cscript //nologo "%~dp0\evaluate_tmp_67354.vbs"') do @SET "%%a" 
	DEL "%~dp0\evaluate_tmp_67354.vbs"
	GOTO :eof
REM

:GetSingleFolder
	REM Use parameter/argument syntax (percent~dp0, etc) to get the last folder in a path.
	SET singleFolder=
	SET "singleFolder=%~1"
	SET "singleFolder=!singleFolder:.=!"
	CALL :GetSingleFolderPart2 "!singleFolder!"
	GOTO :eof
	:GetSingleFolderPart2
		SET "singleFolder=%~n1"
		GOTO :eof
	REM
REM

:ShortenVar
	SET varToShorten=
	SET whatToShorten=
	SET varToShorten=%1
	SET whatToShorten=!%varToShorten%!
	SET lenLim=%2
	
	REM Only shortens the variable if the users' settings say it should. Otherwise, it just inserts an ellipsis.
	if "!setting_shortenOutput!"=="TRUE" (
		if "!whatToShorten:~0,%lenLim%!"=="!whatToShorten!" (
			REM If the variable is already short enough, just send back the input.
			SET shortened=!whatToShorten!
		) else (
			REM Remove certain characters
			SET whatToShorten=!whatToShorten: =!
			SET whatToShorten=!whatToShorten:a=!
			SET whatToShorten=!whatToShorten:e=!
			SET whatToShorten=!whatToShorten:i=!
			SET whatToShorten=!whatToShorten:o=!
			SET whatToShorten=!whatToShorten:u=!
			SET whatToShorten=!whatToShorten:-=!
			SET whatToShorten=!whatToShorten:^(=!
			SET whatToShorten=!whatToShorten:^)=!
			SET whatToShorten=!whatToShorten:^:=!
			SET whatToShorten=!whatToShorten:'=!
			SET whatToShorten=!whatToShorten:,=!
			SET whatToShorten=!whatToShorten:+=!
			if "!whatToShorten:~0,%lenLim%!"=="!whatToShorten!" (
				REM If it is now short enough, return the current value.
				SET shortened=!whatToShorten!
			) else (
				REM If it still isn't short enough, insert an ellipsis
				CALL :InsertEllipsis
			)
		)
	) else (
		if "!whatToShorten:~0,%lenLim%!"=="!whatToShorten!" (
			REM If the variable is already short enough, just send back the input.
			SET shortened=!whatToShorten!
		) else (
			REM If it is too long, insert an ellipsis.
			CALL :InsertEllipsis
		)
	)
	GOTO :eof
	:InsertEllipsis
		REM Insert an ellipsis depending on the user's setting. Return the result of this.
		if "!setting_showEllipsis!"=="START" SET /a relevantLen=!lenLim!-3
		if "!setting_showEllipsis!"=="START" SET shortened=...!whatToShorten:~-%relevantLen%!
		if "!setting_showEllipsis!"=="END" SET /a relevantLen=!lenLim!-3
		if "!setting_showEllipsis!"=="END" SET shortened=!whatToShorten:~0,%relevantLen%!...
		if "!setting_showEllipsis!"=="MIDDLE" SET /a relevantLen=!lenLim!-28
		if "!setting_showEllipsis!"=="MIDDLE" SET shortened=!whatToShorten:~0,25!...!whatToShorten:~-%relevantLen%!
		if "!setting_showEllipsis!"=="NONE" SET shortened=!whatToShorten!
		
		GOTO :eof
	REM
REM

:###############################################################---Special-Functions---######################################################

:ManualMode
	:StartManualMode
	REM clear the screen, while causing a slight pause.
	TIMEOUT 0.5 2>nul & TIMEOUT 0.5 2>nul & TIMEOUT 0.5 2>nul & TIMEOUT 0.5 2>nul
	
	ECHO ********************************* MANUAL MODE *********************************
	ECHO:
	ECHO Enter the path of the containing folder (folders inside this will be listed
	ECHO with their sizes)
	ECHO Type :S: to open the settings menu.
	ECHO:
	SET manualInput=
	SET /p "manualInput=>>>"
	ECHO:
	
	if NOT DEFINED manualInput ECHO Invalid Input & PAUSE>nul & GOTO StartManualMode
	if /I "!manualInput!"==":S:" CALL :OptionsMenu & GOTO StartManualMode
	CD "!manualInput!" 2>nul || ( ECHO The folder could not be found & PAUSE>nul & GOTO StartManualMode )
	
	SET "param1=!manualInput!"
	SET "param2="
	CALL :ShortenVar manualInput 57
	ECHO Scanning folders in: "!shortened!"
	<nul set /p "var=Press any key to continue . . . " & PAUSE>nul & ECHO !Clr10!!Clr10!!Clr10!!Clr1!!Clr1!
	
	GOTO :eof
	
	:OptionsMenu
		:StartOptionsMenu
		TIMEOUT 0.5 2>nul & TIMEOUT 0.5 2>nul & TIMEOUT 0.5 2>nul & TIMEOUT 0.5 2>nul
		
		ECHO *********************************** SETTINGS **********************************
		ECHO Type (Setting)-(Value) to change settings
		ECHO Possible Settings:
		ECHO     1^=        - Whether to shorten folder and path names
		ECHO         ^=A      - Yes   (C\Smthng\SmFldr\FlVrsn2.txt)
		ECHO         ^=B      - No    (C:\Something\Some Folder\File - Version 2.txt)
		ECHO     2^=        - Where to show an ellipsis (...) in long folder and path names
		ECHO         ^=A      - In the middle         (C:\Someth...ath\folder)
		ECHO         ^=B      - At the start          (...ng\long path\folder)
		ECHO         ^=C      - At the end            (C:\Something\long p...)
		ECHO         ^=D      - Do not show ellipses   (C:\Something\long path\folder)
		ECHO     3^=        - What to show when displaying where folder-links point to
		ECHO         ^=A      - Show paths
		ECHO         ^=B      - Show folder names
		ECHO         ^=C      - Don't show anything
		ECHO For example, type '1^=B' to turn off shortening path and folder names
		ECHO Type :E: to exit the setting menu.
		ECHO Type (Setting)^? to display the setting's current value.
		
		:OptionsMenuInput
		
		SET settingInput=
		SET /p settingInput=^>^>^>
		SET validSetting=False
		
		if NOT DEFINED settingInput ECHO Invalid Input & PAUSE>nul & GOTO StartOptionsMenu
		if /I "!settingInput!"==":E:" GOTO :eof
		
		if "!settingInput!"=="1?" SET validSetting=Query & ECHO Currently set to: !setting_shortenOutput!
		if /I "!settingInput!"=="1=A" ECHO TRUE>"%~dp0\Settings\setting_shortenOutput.txt"	& CALL :UpdateSettings 1 TRUE
		if /I "!settingInput!"=="1=B" ECHO FALSE>"%~dp0\Settings\setting_shortenOutput.txt"	& CALL :UpdateSettings 1 FALSE
		
		if "!settingInput!"=="2?" SET validSetting=Query & ECHO Currently set to: !setting_showEllipsis!
		if /I "!settingInput!"=="2=A" ECHO MIDDLE>"%~dp0\Settings\setting_showEllipsis.txt"	& CALL :UpdateSettings 2 MIDDLE
		if /I "!settingInput!"=="2=B" ECHO START>"%~dp0\Settings\setting_showEllipsis.txt"	& CALL :UpdateSettings 2 START
		if /I "!settingInput!"=="2=C" ECHO END>"%~dp0\Settings\setting_showEllipsis.txt"	& CALL :UpdateSettings 2 END
		if /I "!settingInput!"=="2=D" ECHO NONE>"%~dp0\Settings\setting_showEllipsis.txt"	& CALL :UpdateSettings 2 NONE
		
		if "!settingInput!"=="3?" SET validSetting=Query & ECHO Currently set to: !setting_lnkPathType!
		if /I "!settingInput!"=="3=A" ECHO PATHS>"%~dp0\Settings\setting_lnkPathType.txt"	& CALL :UpdateSettings 3 PATHS
		if /I "!settingInput!"=="3=B" ECHO NAMES>"%~dp0\Settings\setting_lnkPathType.txt"	& CALL :UpdateSettings 3 NAMES
		if /I "!settingInput!"=="3=C" ECHO NONE>"%~dp0\Settings\setting_lnkPathType.txt"	& CALL :UpdateSettings 3 NONE
		
		
		if "%validSetting%"=="False" ECHO Invalid Input
		
		
		GOTO OptionsMenuInput
		
		
		
		:UpdateSettings
			SET validSetting=True
			SET /p setting_shortenOutput=<"%~dp0\Settings\setting_shortenOutput.txt"
			SET /p setting_showEllipsis=<"%~dp0\Settings\setting_showEllipsis.txt"
			SET /p setting_lnkPathType=<"%~dp0\Settings\setting_lnkPathType.txt"
			ECHO Setting #%1 updated to '%2'
			GOTO :eof
		REM
	REM
REM

:InstallDirError
	TITLE ERROR: Invalid Install-Directory
	ECHO ERROR(8): Problematic characters detected in the install directory.
	ECHO(
	ECHO    The directory is:
	ECHO %~dp0
	ECHO(
	ECHO    This directory is invalid, as cmd.exe has already removed any problematic
	ECHO    characters. Compare this path to the path shown in the title bar of windows
	ECHO    explorer. This will show which characters have been removed.
	ECHO(
	ECHO    Because of this, the Folder Sizes program cannot be unpacked, and/or the
	ECHO    unpacked files cannot be accessed. Please rename the directories in the
	ECHO    install-path, or install in a different location.
	ECHO(
	ECHO    The most likely character to be a problem is an exclamation mark.
	ECHO    Other characters include: ^& ^%% ^^, and possibly also ^( ^) ^. ^' ^[ ^] ^{ ^} ^; ^,
	ECHO    Non-keyboard (extended ascii and unicode) characters can also be problematic.
	ECHO(
	ECHO Press any key to exit . . . & PAUSE>nul & EXIT
REM

:UNPACK
	TITLE Folder_Sizes_Installer
	ECHO(
	ECHO Unpacking within the install directory:
	SET installDir=%~dp0
	if "!installDir:~0,71!"=="!installDir!" ( ECHO 	!installDir! ) else ( ECHO 	!installDir:~0,68!... )
	
	:#CreateFolders
		MD "%~dp0\Settings"
		MD "%~dp0\Previous Folders"
	REM
	
	:#CreateParseLnk
		DEL /A:RH "%~dp0\ParseShortcut.vbs"  2>nul
		ECHO set WshShell = WScript.CreateObject("WScript.Shell")>"%~dp0\ParseShortcut.vbs" 
		ECHO set Lnk = WshShell.Createshortcut(WScript.Arguments(0))>>"%~dp0\ParseShortcut.vbs" 
		ECHO WScript.Echo Lnk.TargetPath>>"%~dp0\ParseShortcut.vbs"  
	REM
	
	:#CreateSettings
		ECHO TRUE>"%~dp0\Settings\setting_shortenOutput.txt"
		ECHO MIDDLE>"%~dp0\Settings\setting_showEllipsis.txt"
		ECHO PATHS>"%~dp0\Settings\setting_lnkPathType.txt"
	REM
	
	:#CreateHasUnpacked
		if EXIST "%~dp0\ParseShortcut.vbs" (
			if EXIST "%~dp0\Settings\setting_shortenOutput.txt" (
				if EXIST "%~dp0\Settings\setting_showEllipsis.txt" (
					if EXIST "%~dp0\Settings\setting_lnkPathType.txt" (
						ECHO This file tells the Folder Sizes program not to unpack again.>"%~dp0\hasUnpacked.txt"
						ECHO(>>"%~dp0\hasUnpacked.txt"
						ECHO To reset the unpacked files, delete them, delete this file, and then run the Folder Sizes program.>>"%~dp0\hasUnpacked.txt"
						ECHO Note: All of the files that it has unpacked will be reset.>>"%~dp0\hasUnpacked.txt"
						ECHO(>>"%~dp0\hasUnpacked.txt"
						ECHO(>>"%~dp0\hasUnpacked.txt"
						ECHO  - Alex17319>>"%~dp0\hasUnpacked.txt"
					)
				)
			)
		)
	REM
	
	<nul set /p "var=Finished unpacking. Press any key to continue . . . " & PAUSE>nul & ECHO(
	TITLE Folder_Sizes
	ECHO(
	GOTO :eof
REM

:#Sources
	REM Many, mainly from:
		REM StackOverflow
		REM SuperUser
		REM Google Groups
		REM DOSTips
		REM w3Schools (for html)
		REM ss64
		REM WikiHow (for html)
		REM Computer Hope
		REM msdn.microsoft.com, blogs.msdn.com, and other microsoft sites
		REM theasciicode.com
		REM How-To Geek
		REM Technet (social.technet.microsoft.com, blogs.technet.com)
		REM /* Steve Jansen */ (steve-jansen.github.io)
		REM Rob van der Woude's scripting pages
		REM Possibly more
REM

:END
