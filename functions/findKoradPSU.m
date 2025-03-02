function [found, port] = findKoradPSU()
% findKoradPSU Detects Korad Power Supply Unit
%
% Outputs:
% found - Logical indicating if Korad PSU was found
% port  - COM port of the Korad PSU (empty if not found)

% Start with debug messages
disp('=== Starting Korad PSU detection ===');

% Determine the full path to the PowerShell script
scriptPath = fullfile(fileparts(mfilename('fullpath')), 'TestPorts.ps1');
disp(['PowerShell script path: ', scriptPath]);

% Use full path to PowerShell script
psCmd = ['powershell -ExecutionPolicy Bypass -File "', scriptPath, '"'];
disp(['Running command: ', psCmd]);

% Run the PowerShell command
[status, cmdOutput] = system(psCmd);
disp(['Command execution status: ', num2str(status)]);

% Initialize outputs
found = false;
port = '';

if status == 0
    disp('Command executed successfully, parsing output...');
    
    % The output is mixed with PowerShell job info and JSON
    % First, look for a JSON object in curly braces
    jsonMatch = regexp(cmdOutput, '\{[^{}]*"Response"[^{}]*\}', 'match');
    
    if ~isempty(jsonMatch)
        disp('Found JSON data in the output');
        
        % Try to parse each JSON object found
        for i = 1:length(jsonMatch)
            try
                jsonObj = jsondecode(jsonMatch{i});
                
                % Check if this is a response from a port
                if isfield(jsonObj, 'Response') && isfield(jsonObj, 'Port')
                    responseStr = jsonObj.Response;
                    portStr = jsonObj.Port;
                    
                    % Print what we found
                    disp(['Port: ', portStr, ' Response: "', responseStr, '"']);
                    
                    % Check for Korad in the response (case insensitive)
                    if contains(lower(responseStr), 'korad')
                        disp(['Found Korad device on port ', portStr, '!']);
                        found = true;
                        port = portStr;
                        break;  % Stop after finding the first Korad device
                    end
                end
            catch jsonErr
                disp(['Error parsing JSON object: ', jsonErr.message]);
                disp(['Problem JSON: ', jsonMatch{i}]);
            end
        end
    else
        disp('No JSON data found in command output');
        disp('--- Raw Command Output ---');
        disp(cmdOutput);
        disp('--- End Raw Output ---');
    end
else
    warning('PowerShell:ScriptError', 'Error running the PowerShell script.');
    disp(['Error running the PowerShell script. Status code: ', num2str(status)]);
    disp('--- Raw Command Output ---');
    disp(cmdOutput);
    disp('--- End Raw Output ---');
end

% Final result
if found
    disp(['=== Detection complete: Korad PSU found on port ', port, ' ===']);
else
    disp('=== Detection complete: No Korad PSU found ===');
end

end