function beerPong(s)
% beerPong controls the PSU for the Beer Pong game
% It gets a power percentage from the user (0-100%),
% sets PSU voltage between 3.5V (0%) and 7V (100%),
% turns on the PSU for a fixed duration, then turns it off,
% and enters an interactive loop allowing the user to update the power or exit.
%
% Inputs:
%   s - Serial port object for communicating with the PSU.

% Define voltage range
minVoltage = 3.5;  % 0% power = 3.5V
maxVoltage = 7.0;  % 100% power = 7.0V

% Fixed current setting of 2.2A for all power levels
currentSetting = 2.2;  % 2.2 amps for all power levels

% Fixed timing for how long the PSU stays on per update
fixedTiming = 3.0;  % 3.0 seconds
cooldownTime = 2.0; % 2.0 seconds cooldown after turning off

% Get initial power percentage from user
levelInput = input('Enter power percentage (0-100), "d" for drunk mode, or "e" to cancel: ', 's');
if strcmpi(levelInput, 'e')
    disp('Beer Pong game cancelled.');
    return;
end

% Check for drunk mode
drunkMode = false;
if strcmpi(levelInput, 'd')
    drunkMode = true;
    disp('DRUNK MODE ACTIVATED! Random power levels will be used.');
    % Start with a random power percentage between 45% and 75%
    powerPercent = randi([45, 75]);
else
    % Convert to number and validate
    powerPercent = str2double(levelInput);
    if isnan(powerPercent) || powerPercent < 0 || powerPercent > 100
        disp('Invalid power percentage. Must be a number between 0 and 100, or "d" for drunk mode.');
        return;
    end
end

% Main game loop
while true
    % Calculate voltage based on power percentage
    voltageToSet = minVoltage + (powerPercent / 100) * (maxVoltage - minVoltage);
    
    % Display mode and power info
    if drunkMode
        fprintf('DRUNK MODE: Setting Beer Pong power to %d%%\n', round(powerPercent));
    else
        fprintf('Setting Beer Pong power to %d%%\n', round(powerPercent));
    end
    fprintf('Voltage = %.2f V, Current = %.2f A\n', voltageToSet, currentSetting);
    fprintf('PSU will be activated for %d seconds\n', fixedTiming);

    % First make sure PSU is off to start with a clean state
    write(s, "OUT0", "string");
    pause(0.5);

    % Clear any pending data
    flush(s);

    % Send commands to set the voltage and current
    write(s, sprintf("VSET1:%.2f", voltageToSet), "string");
    pause(0.3); % Longer pause for stabilization
    write(s, sprintf("ISET1:%.3f", currentSetting), "string");
    pause(0.3);

    % Now force PSU on with multiple attempts if needed
    disp('Activating PSU output...');
    for attempt = 1:3
        write(s, "OUT1", "string");
        pause(0.5);
        
        % Try to verify if it's on
        write(s, "STATUS?", "string");
        pause(0.3);
        
        if s.NumBytesAvailable > 0
            status = read(s, s.NumBytesAvailable, "string");
            if ~isempty(status)
                disp('PSU output is now ACTIVE.');
                break;
            end
        end
        
        if attempt < 3
            disp(['Attempt ' num2str(attempt) ' failed. Trying again...']);
        else
            disp('Could not verify PSU status. Continuing anyway...');
        end
    end

    % Allow PSU to remain on for the fixed duration with countdown
    disp(['PSU will remain active for ' num2str(fixedTiming) ' seconds']);
    startTime = tic;
    
    % For drunk mode, randomize power during the activation period
    initialPower = powerPercent;
    
    for i = fixedTiming:-1:1
        % In drunk mode, randomly adjust power within ±10% of initial setting
        if drunkMode && i < fixedTiming  % Skip the first iteration to establish baseline
            % Calculate random fluctuation within ±10% of initial power
            fluctuation = (rand() * 20) - 10;  % Random number between -10 and +10
            newPowerPercent = initialPower + fluctuation;
            
            % Ensure power stays within 45-75% range
            newPowerPercent = max(45, min(75, newPowerPercent));
            
            % Calculate new voltage based on adjusted power
            newVoltage = minVoltage + (newPowerPercent / 100) * (maxVoltage - minVoltage);
            
            % Apply the new voltage
            write(s, sprintf("VSET1:%.2f", newVoltage), "string");
            
            % Display the power fluctuation
            fprintf('DRUNK MODE: Power fluctuated to %.1f%% (%.2fV)\n', newPowerPercent, newVoltage);
        end
        
        fprintf('Time remaining: %d second(s)\n', i);
        pause(1);
    end
    
    actualTime = toc(startTime);
    fprintf('PSU was active for %.1f seconds\n', actualTime);

    % Deactivate the PSU after the fixed duration
    disp('Time complete. Deactivating PSU output...');
    write(s, "OUT0", "string");
    pause(0.3);
    % Force it off again to be sure
    write(s, "OUT0", "string");
    pause(0.5);
    disp('PSU output is now INACTIVE.');
    
    % Cooldown period
    disp(['Cooldown period: ' num2str(cooldownTime) ' seconds']);
    for i = cooldownTime:-1:1
        fprintf('Cooldown: %d second(s)\n', i);
        pause(1);
    end
    disp('Cooldown complete.');

    % Ask user for next power level or exit
    userInput = input('Enter power percentage (0-100), "d" for drunk mode, or "e" to exit: ', 's');
    if strcmpi(userInput, 'e')
        break;
    end
    
    % Check for drunk mode toggle
    if strcmpi(userInput, 'd')
        drunkMode = true;
        disp('DRUNK MODE ACTIVATED! Random power levels will be used.');
        powerPercent = randi([0, 100]);
        continue;
    end
    
    % If drunk mode is active, ignore user input and set random level
    if drunkMode
        powerPercent = randi([45, 75]);
        disp('DRUNK MODE: Random power level selected!');
    else
        % Process normal user input
        newPowerPercent = str2double(userInput);
        if isnan(newPowerPercent) || newPowerPercent < 0 || newPowerPercent > 100
            disp('Invalid input. Using previous power level.');
        else
            powerPercent = newPowerPercent;
        end
    end
end

% Ensure PSU is off when exiting
write(s, "OUT0", "string");
pause(0.3);
write(s, "OUT0", "string");
pause(0.3);
disp('PSU output confirmed INACTIVE.');
disp('Beer Pong game ended.');
end