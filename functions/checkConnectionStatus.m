function checkConnectionStatus(~, ~)
% checkConnectionStatus periodically checks if the Korad PSU is still connected
% and updates the global connection status variable.
%
% This function is designed to be called by a timer and uses the global SerialObj.

global KoradConnectionStatus SerialObj;

% First check if we have a valid serial object
if isempty(SerialObj)
    if KoradConnectionStatus
        disp('Warning: Connection to Korad PSU has been lost (serial object invalid). Use option "r" to reconnect.');
        KoradConnectionStatus = false;
    end
    return;
end

try
    % Try a simple command to check if the connection is still alive
    write(SerialObj, "*IDN?", "string");
    pause(0.5);
    
    if SerialObj.NumBytesAvailable > 0
        read(SerialObj, SerialObj.NumBytesAvailable, "string");  % Read but don't need to store the result
        
        if ~KoradConnectionStatus
            % Connection was restored, log this event
            disp('Connection to Korad PSU has been restored.');
            KoradConnectionStatus = true;
        else
            % Still connected, no need to log anything
            KoradConnectionStatus = true;
        end
    else
        if KoradConnectionStatus
            % Connection was lost, log this event
            disp('Warning: Connection to Korad PSU has been lost. Use option "r" to reconnect.');
            KoradConnectionStatus = false;
        else
            % Still disconnected, no need to log again
            KoradConnectionStatus = false;
        end
    end
catch
    if KoradConnectionStatus
        % Connection was lost, log this event
        disp('Warning: Connection to Korad PSU has been lost. Use option "r" to reconnect.');
        KoradConnectionStatus = false;
    else
        % Still disconnected, no need to log again
        KoradConnectionStatus = false;
    end
end

end