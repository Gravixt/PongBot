% Final Korad Power Supply Controller with Auto-Detection
% Complete controller with reliable auto-detection and live readings

% Clear workspace and command window
clear all;
clc;
clear liveUpdateCallback;  % Clear any previous definitions of liveUpdateCallback

% Create logs and figures directories if they don't exist
scriptPath = fileparts(mfilename('fullpath'));
logsFolder = fullfile(scriptPath, 'logs');
figuresFolder = fullfile(scriptPath, 'figures');

% Create logs folder if it doesn't exist
if ~exist(logsFolder, 'dir')
    mkdir(logsFolder);
    disp('Created logs directory.');
end

% Create figures folder if it doesn't exist
if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
    disp('Created figures directory.');
end

% Create timestamp for this session
timestamp = datestr(now, 'dd-mmm-yyyy_HH-MM-SS');

% Start logging
logFileName = ['korad_log_', timestamp, '.txt'];
logFile = fullfile(logsFolder, logFileName);
if exist(logFile, 'file')
    diary off; % Ensure any previous diary is closed
end
diary(logFile);
disp(['=== Korad Controller Session Start: ', datestr(now), ' ===']);
disp(['Log file: ', logFile]);

% ----- PORT DETECTION SECTION -----
disp('=== Port Detection Phase ===');
disp(['Detection start time: ', datestr(now)]);

% Add the port recognition handling folder to MATLAB path to ensure we can call the function
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));

% Use the auto-detector function to find Korad PSU
[foundKoradPort, detectedPort] = findKoradPSU();

% Check detection result
if ~foundKoradPort
    disp('No Korad power supply detected.');
    diary off;
    return;
end

disp(['Selected port for connection: ', char(detectedPort)]);
disp(['Detection end time: ', datestr(now)]);
disp('=== End of Detection Phase ===');
disp(' ');

% ----- CONTROLLER SECTION -----

% Configuration parameters
portName = detectedPort;  % Use the detected port
baudRate = 9600;          % Default baud rate for Korad power supplies
dataBits = 8;             % Data bits
parity = "none";          % Parity
stopBits = 1;             % Stop bits
flowControl = "none";     % Flow control

% Global variable to track connection status
global KoradConnectionStatus SerialObj;
KoradConnectionStatus = false;
SerialObj = [];  % Global serial object that will be shared with timers

% Global variable for timers
global ConnectionMonitorTimer LiveTimer;
ConnectionMonitorTimer = [];
LiveTimer = [];

% Resolution for timer updates
resolution = 1; % resolution (in seconds) for oscilloscope and readings

try
    % Create the connection
    disp(['Connecting to Korad power supply on port ', portName, '...']);
    SerialObj = serialport(portName, baudRate, "DataBits", dataBits, ...
                   "Parity", parity, "StopBits", stopBits, ...
                   "FlowControl", flowControl);
               
    % Set timeout
    SerialObj.Timeout = 2;
    
    % Clear any existing data
    flush(SerialObj);
    
    % Test connection
    disp('Testing connection to Korad power supply...');
    write(SerialObj, "*IDN?", "string");
    pause(1);
    
    if SerialObj.NumBytesAvailable > 0
        response = read(SerialObj, SerialObj.NumBytesAvailable, "string");
        disp(['Device response: ', response]);
        disp('Connection successful!');
        KoradConnectionStatus = true;
    else
        disp('No response from device. Check connections and try again.');
        clear SerialObj;
        SerialObj = [];
        diary off;
        return;
    end
    
    % ----- CONNECTION MONITOR TIMER -----
    % Create a timer to periodically check if the connection is still alive
    ConnectionMonitorTimer = timer('ExecutionMode', 'fixedRate', 'Period', 5, ...
        'TimerFcn', @checkConnectionStatus);
    start(ConnectionMonitorTimer);
    
    % ----- LIVE READINGS FIGURE & TIMER -----
    % Create a timer object to update live readings
    LiveTimer = timer('ExecutionMode','fixedRate','Period',resolution, ...
        'TimerFcn', @liveUpdateCallback);
    start(LiveTimer);
    
    % ----- CONTROL MENU -----
    while true
        disp('');
        disp('=== Korad Power Supply Control ===');
        % Display connection status
        if KoradConnectionStatus
            disp('Status: CONNECTED');
        else
            disp('Status: DISCONNECTED - Port may be lost due to sleep/USB disconnect');
            disp('r. Reconnect');
        end
        disp('0. Off');
        disp('1. On');
        disp('2. Run voltage ramp profile');
        disp('3. Save to memory (M1-M5)');
        disp('4. Recall from memory (M1-M5)');
        disp('5. Run custom function');
        disp('v. Quick set voltage');
        disp('c. Quick set current');
        disp('e. Exit');
        
        choice = input('Enter choice: ', 's');
        
        % Check if connection is lost before processing command
        if ~KoradConnectionStatus && ~strcmpi(choice, 'r') && ~strcmpi(choice, 'e')
            disp('⚠️ Device is currently disconnected! Please reconnect first (option r).');
            continue;
        end
        
        % Special case for reconnection
        if strcmpi(choice, 'r')
            if KoradConnectionStatus
                disp('Device is already connected.');
                continue;
            end
            
            % First, clean up all existing resources
            cleanupResources();
            
            % Try to detect the port again
            disp('Trying to re-detect Korad PSU...');
            [foundKoradPort, detectedPort] = findKoradPSU();
            
            if ~foundKoradPort
                disp('Failed to detect Korad PSU. Please check connections and try again.');
                continue;
            end
            
            portName = detectedPort;
            disp(['Korad PSU detected on port: ', char(portName)]);
            
            % Create new connection
            try
                SerialObj = serialport(portName, baudRate, "DataBits", dataBits, ...
                           "Parity", parity, "StopBits", stopBits, ...
                           "FlowControl", flowControl);
                SerialObj.Timeout = 2;
                flush(SerialObj);
                
                % Test connection
                write(SerialObj, "*IDN?", "string");
                pause(1);
                
                if SerialObj.NumBytesAvailable > 0
                    response = read(SerialObj, SerialObj.NumBytesAvailable, "string");
                    disp(['Device response: ', response]);
                    disp('Reconnection successful!');
                    KoradConnectionStatus = true;
                    
                    % Clear LiveHandles to force recreation of the figure
                    global LiveHandles;
                    LiveHandles = [];
                    
                    % Close any existing figure windows
                    close all;
                    
                    % Create new timers
                    ConnectionMonitorTimer = timer('ExecutionMode', 'fixedRate', 'Period', 5, ...
                        'TimerFcn', @checkConnectionStatus);
                    start(ConnectionMonitorTimer);
                    
                    LiveTimer = timer('ExecutionMode','fixedRate','Period',resolution, ...
                        'TimerFcn', @liveUpdateCallback);
                    start(LiveTimer);
                    
                    disp('Live display has been completely reset.');
                else
                    disp('No response from device. Check connections and try again.');
                    KoradConnectionStatus = false;
                end
            catch reconnectErr
                disp(['Error during reconnection: ', reconnectErr.message]);
                KoradConnectionStatus = false;
            end
            
            continue;
        end
        
        % Process exit command first: turn off PSU before exiting
        if strcmpi(choice, 'e')
            % Prompt for saving live graph
            saveGraphChoice = input('Would you like to save the live update graph? (y/n): ', 's');
            if strcmpi(saveGraphChoice, 'y')
                fileName = input('Enter file name (press enter for default): ', 's');
                if isempty(fileName)
                    fileName = ['korad_graph_', timestamp, '.png'];
                else
                    if ~endsWith(fileName, '.png')
                        fileName = [fileName, '.png'];
                    end
                end
                % Construct full path to save in figures folder
                fullFilePath = fullfile(figuresFolder, fileName);
                
                % Retrieve the working live window via the global variable
                global LiveHandles
                if ~isempty(LiveHandles) && isfield(LiveHandles, 'hLiveFig') && ishandle(LiveHandles.hLiveFig)
                    try
                        saveas(LiveHandles.hLiveFig, fullFilePath);
                        disp(['Live update graph saved as ', fullFilePath]);
                    catch err
                        disp(['Error saving live update graph: ', err.message]);
                    end
                else
                    disp('No valid live update window found to save.');
                end
            end
            
            % Turn PSU OFF if connected
            if KoradConnectionStatus && ~isempty(SerialObj)
                disp('Turning PSU OFF and closing connection...');
                try
                    write(SerialObj, "OUT0", "string");
                    pause(0.5);  % Allow time for the PSU to process the command
                catch
                    disp('Warning: Unable to turn off PSU due to connection issues.');
                end
            else
                disp('Exiting without turning off PSU (not connected).');
            end
            
            % Clean up resources safely
            cleanupResources();
            
            disp(['=== Korad Controller Session End: ', datestr(now), ' ===']);
            diary off;
            disp(['Log file saved to: ', logFile]);
            return;
        elseif strcmpi(choice, 'v')
            % Quick set voltage
            newVoltage = input('Enter voltage (0-30V): ');
            if newVoltage >= 0 && newVoltage <= 30
                command = sprintf("VSET1:%.2f", newVoltage);
                disp(['Setting voltage to ', num2str(newVoltage), 'V...']);
                try
                    write(SerialObj, command, "string");
                    disp('Voltage set successfully.');
                catch
                    disp('Error: Failed to set voltage. Connection may be lost.');
                    KoradConnectionStatus = false;
                end
            else
                disp('Invalid voltage value. Must be between 0 and 30V.');
            end
            continue;
        elseif strcmpi(choice, 'c')
            % Quick set current
            newCurrent = input('Enter current (0-5A): ');
            if newCurrent >= 0 && newCurrent <= 5
                command = sprintf("ISET1:%.3f", newCurrent);
                disp(['Setting current to ', num2str(newCurrent), 'A...']);
                try
                    write(SerialObj, command, "string");
                    disp('Current set successfully.');
                catch
                    disp('Error: Failed to set current. Connection may be lost.');
                    KoradConnectionStatus = false;
                end
            else
                disp('Invalid current value. Must be between 0 and 5A.');
            end
            continue;
        end
        
        % Convert input to number if possible
        numChoice = str2double(choice);
        if isnan(numChoice)
            disp('Invalid choice. Please enter a valid option.');
            continue;
        end
        
        switch numChoice
            case 0
                % Option 0: Turn output OFF
                disp('Turning output OFF...');
                try
                    write(SerialObj, "OUT0", "string");
                    disp('Output turned OFF.');
                catch
                    disp('Error: Failed to turn output OFF. Connection may be lost.');
                    KoradConnectionStatus = false;
                end
                
            case 1
                % Option 1: Turn output ON
                disp('Turning output ON...');
                try
                    write(SerialObj, "OUT1", "string");
                    disp('Output turned ON.');
                catch
                    disp('Error: Failed to turn output ON. Connection may be lost.');
                    KoradConnectionStatus = false;
                end
                
            case 2
                % Option 2: Run voltage ramp profile
                disp('Running voltage ramp profile...');
                startV = input('Enter start voltage (0-30V): ');
                endV = input('Enter end voltage (0-30V): ');
                
                if startV < 0 || startV > 30 || endV < 0 || endV > 30
                    disp('Invalid voltage range. Must be between 0 and 30V.');
                    continue;
                end
                
                % Ask user for their preferred method
                methodChoice = input('Specify by (s)tep size or (n)umber of steps? ', 's');
                
                % Process based on user choice
                if strcmpi(methodChoice, 's')
                    % Step size method
                    voltStep = input('Enter voltage step size (0.01-10V): ');
                    
                    if voltStep < 0.01 || voltStep > 10
                        disp('Invalid voltage step. Must be between 0.01V and 10V.');
                        continue;
                    end
                    
                    % Calculate number of steps based on voltage step
                    steps = round(abs(endV - startV) / voltStep);
                    
                elseif strcmpi(methodChoice, 'n')
                    % Number of steps method
                    steps = input('Enter number of steps: ');
                    
                    if steps < 1 || steps > 3000
                        disp('Invalid number of steps. Must be between 1 and 3000.');
                        continue;
                    end
                    
                    % Calculate step size based on number of steps
                    voltStep = abs(endV - startV) / steps;
                    
                else
                    disp('Invalid choice. Please enter "s" for step size or "n" for number of steps.');
                    continue;
                end
                
                stepTime = input('Enter time per step (seconds): ');
                
                % Safety check for too many steps
                if steps > 1000
                    tooManySteps = input('Warning: This will create over 1000 steps. Continue? (y/n): ', 's');
                    if ~strcmpi(tooManySteps, 'y')
                        disp('Voltage ramp cancelled.');
                        continue;
                    end
                end
                
                % Display total steps and estimated time
                estTime = steps * stepTime;
                disp(['Total steps: ', num2str(steps)]);
                disp(['Voltage step size: ', num2str(voltStep, '%.4f'), 'V']);
                disp(['Estimated time: ', num2str(estTime), ' seconds (', num2str(estTime/60, '%.1f'), ' minutes)']);
                
                % Ask if the PSU should turn off after ramp testing BEFORE starting the ramp
                turnOffAfter = input('Would you like the PSU to turn off after ramp testing? (y/n): ', 's');
                
                % Recalculate precise voltage step to ensure we hit the end voltage
                if steps > 0
                    voltageStep = (endV - startV) / steps;
                else
                    voltageStep = 0;
                    steps = 0;
                end
                
                % Temporarily pause the connection monitor to avoid interference during the ramp
                if ~isempty(ConnectionMonitorTimer) && isvalid(ConnectionMonitorTimer)
                    stop(ConnectionMonitorTimer);
                end
                
                % Wrap the entire ramp in a try-catch to handle disconnection during ramp
                try
                    % Set the voltage to the starting value and wait 0.5 seconds to allow stabilization
                    disp(['Setting initial voltage to ', num2str(startV), 'V and waiting for stabilization...']);
                    command = sprintf("VSET1:%.2f", startV);
                    write(SerialObj, command, "string");
                    pause(0.5);
                    
                    % Turn output ON and begin the ramp test
                    disp('Turning output ON...');
                    write(SerialObj, "OUT1", "string");
                    disp('Starting voltage ramp...');
                    
                    % Create a progress indicator
                    progressStep = max(1, floor(steps / 20)); % Update progress about 20 times during the ramp
                    
                    for i = 0:steps
                        % Check if the connection is still alive
                        if ~KoradConnectionStatus
                            disp('⚠️ Connection lost during voltage ramp! Aborting ramp.');
                            break;
                        end
                        
                        currentV = startV + (i * voltageStep);
                        command = sprintf("VSET1:%.2f", currentV);
                        write(SerialObj, command, "string");
                        
                        % Only show detailed output for specific steps to reduce console spam
                        if mod(i, progressStep) == 0 || i == steps
                            disp(['Step ', num2str(i+1), '/', num2str(steps+1), ': Voltage set to ', num2str(currentV, '%.2f'), 'V']);
                            
                            pause(0.2);
                            write(SerialObj, "VOUT1?", "string");
                            pause(0.3);
                            if SerialObj.NumBytesAvailable > 0
                                actualV = read(SerialObj, SerialObj.NumBytesAvailable, "string");
                                disp(['Measured voltage: ', actualV, 'V']);
                            end
                        end
                        
                        pause(stepTime);
                    end
                    
                    if KoradConnectionStatus
                        disp('Voltage ramp complete.');
                        
                        % Process the predetermined off option
                        if strcmpi(turnOffAfter, 'y')
                            disp('Turning output OFF after ramp test...');
                            write(SerialObj, "OUT0", "string");
                            disp('Output turned OFF.');
                        else
                            disp('Leaving output state unchanged.');
                        end
                    end
                catch rampErr
                    disp(['Error during voltage ramp: ', rampErr.message]);
                    KoradConnectionStatus = false;
                end
                
                % Restart the connection monitor
                if ~isempty(ConnectionMonitorTimer) && isvalid(ConnectionMonitorTimer)
                    start(ConnectionMonitorTimer);
                end
                
            case 3
                % Option 3: Save current settings to memory (M1-M5)
                disp('Saving current settings to memory...');
                memorySlot = input('Enter memory slot (1-5): ');
                if memorySlot >= 1 && memorySlot <= 5
                    command = sprintf("SAV%d", memorySlot);
                    disp(['Saving settings to memory slot M', num2str(memorySlot), '...']);
                    try
                        write(SerialObj, command, "string");
                        pause(0.5);
                        disp(['Settings saved to memory slot M', num2str(memorySlot)]);
                    catch
                        disp('Error: Failed to save settings. Connection may be lost.');
                        KoradConnectionStatus = false;
                    end
                else
                    disp('Invalid memory slot. Must be between 1 and 5.');
                end
                
            case 4
                % Option 4: Recall settings from memory (M1-M5)
                disp('Recalling settings from memory...');
                memorySlot = input('Enter memory slot to recall (1-5): ');
                if memorySlot >= 1 && memorySlot <= 5
                    command = sprintf("RCL%d", memorySlot);
                    disp(['Recalling settings from memory slot M', num2str(memorySlot), '...']);
                    try
                        write(SerialObj, command, "string");
                        pause(0.5);
                        
                        write(SerialObj, "VSET1?", "string");
                        pause(0.5);
                        if SerialObj.NumBytesAvailable > 0
                            voltage = read(SerialObj, SerialObj.NumBytesAvailable, "string");
                        else
                            voltage = "unknown";
                        end
                        
                        write(SerialObj, "ISET1?", "string");
                        pause(0.5);
                        if SerialObj.NumBytesAvailable > 0
                            current = read(SerialObj, SerialObj.NumBytesAvailable, "string");
                        else
                            current = "unknown";
                        end
                        
                        disp(['Settings recalled from memory slot M', num2str(memorySlot)]);
                        disp(['Voltage setting: ', voltage, 'V, Current setting: ', current, 'A']);
                    catch
                        disp('Error: Failed to recall settings. Connection may be lost.');
                        KoradConnectionStatus = false;
                    end
                else
                    disp('Invalid memory slot. Must be between 1 and 5.');
                end

            case 5
            % Option 5: Run a custom function from the customFunctions folder
            customFuncName = input('Enter custom function name (without .m extension): ', 's');
            % Define the folder where custom functions are stored:
            customFolder = fullfile(fileparts(mfilename('fullpath')), 'customFunctions');
            % Determine the full path for the requested function file:
            customFilePath = fullfile(customFolder, [customFuncName, '.m']);
            if exist(customFilePath, 'file') == 2
                % Ensure the customFunctions folder is on the path
                if isempty(which(customFuncName))
                    addpath(customFolder);
                end
                
                try
                    % Call the custom function with the SerialObj
                    % The function will handle its own parameter input and logic
                    feval(customFuncName, SerialObj);
                    disp('Custom function completed.');
                catch err
                    disp(['Error executing custom function: ', err.message]);
                    if contains(err.message, 'connected to the serial port')
                        KoradConnectionStatus = false;
                    end
                end
            else
                disp('Custom function not found in the customFunctions folder.');
            end
                        
                    otherwise
                        disp('Invalid choice. Please select one of the listed options.');
                end
                
                pause(0.5);
            end
            
        catch e
            % Error handler
            disp(['Error: ', e.message]);
            
            % Cleanup all resources
            cleanupResources();
            
            disp(['=== Korad Controller Session Terminated with Error: ', datestr(now), ' ===']);
            disp(['Log file saved to: ', logFile]);
            diary off;
        end

% Final cleanup if loop ever exits normally
cleanupResources();

diary off;
disp(['Log file saved to: ', logFile]);
disp('Script ended.');

% Helper function to safely clean up all resources
function cleanupResources()
    global ConnectionMonitorTimer LiveTimer SerialObj LiveHandles;
    
    % Clean up timers
    if ~isempty(ConnectionMonitorTimer) && isvalid(ConnectionMonitorTimer)
        try
            stop(ConnectionMonitorTimer);
            delete(ConnectionMonitorTimer);
        catch
            % Ignore errors during timer cleanup
        end
    end
    ConnectionMonitorTimer = [];
    
    if ~isempty(LiveTimer) && isvalid(LiveTimer)
        try
            stop(LiveTimer);
            delete(LiveTimer);
        catch
            % Ignore errors during timer cleanup
        end
    end
    LiveTimer = [];
    
    % Clean up serial connection
    if ~isempty(SerialObj)
        try
            clear SerialObj;
        catch
            % Ignore errors during cleanup
        end
    end
    SerialObj = [];
    
    % Clear LiveHandles to ensure complete reset
    LiveHandles = [];
    
    % Close all figure windows
    try
        close all;
    catch
        % Ignore errors during figure closing
    end
    
    % Print cleanup confirmation
    disp('All resources have been cleaned up.');
end
