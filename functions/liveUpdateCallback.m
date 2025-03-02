function liveUpdateCallback(~, ~)
% liveUpdateCallback updates the live display with voltage, current, and 
% computed resistance, and plots a moving voltage trace over the last 60 seconds.
% It also shows the voltage and current settings (setpoints).
%
% This function uses the global LiveHandles variable to track UI elements,
% and will completely recreate the visualization when LiveHandles is cleared.

global LiveHandles KoradConnectionStatus SerialObj
persistent tArray voltageArray

% Initialize data arrays if empty
if isempty(tArray)
    tArray = [];
    voltageArray = [];
end

% Check if global LiveHandles exists or needs to be created
if isempty(LiveHandles)
    LiveHandles = struct();
end

% Check if the figure exists; if not, create it from scratch
if ~isfield(LiveHandles, 'hLiveFig') || ~ishandle(LiveHandles.hLiveFig)
    % Create a completely new figure
    hLiveFig = figure('Name','Live PSU Readings','NumberTitle','off',...
        'MenuBar','none','ToolBar','none','Position',[100 100 380 380]);
    
    % Connection status indicator at the top
    hConnectionStatus = uicontrol('Style','text','FontSize',10,'HorizontalAlignment','center',...
        'Position',[10 340 360 30],'String','CONNECTION STATUS: ACTIVE',...
        'BackgroundColor',[0.5 0.9 0.5],'ForegroundColor',[0 0 0]);
    
    % Measured values text display (left)
    hText = uicontrol('Style','text','FontSize',12,'HorizontalAlignment','left',...
        'Position',[10 10 180 80],'String','Waiting for data...');
    
    % Settings values text display (right)
    hSettingsText = uicontrol('Style','text','FontSize',12,'HorizontalAlignment','left',...
        'Position',[200 10 180 80],'String','Settings:\nWaiting for data...');
    
    % Oscilloscope display area
    hOsc = axes('Parent', hLiveFig, 'Position',[0.1 0.45 0.8 0.4], 'Tag','OscilloscopeAxes');
    xlabel(hOsc, 'Time (s) relative to now');
    ylabel(hOsc, 'Voltage (V)');
    title(hOsc, 'Live Voltage Trace');
    grid(hOsc, 'on');
    
    % Store these handles globally
    LiveHandles.hLiveFig = hLiveFig;
    LiveHandles.hText = hText;
    LiveHandles.hSettingsText = hSettingsText;
    LiveHandles.hOsc = hOsc;
    LiveHandles.hConnectionStatus = hConnectionStatus;
    
    % Print creation confirmation
    disp('Created new live visualization window.');
end

% Update connection status indicator in the figure
if isfield(LiveHandles, 'hConnectionStatus') && ishandle(LiveHandles.hConnectionStatus)
    if KoradConnectionStatus
        set(LiveHandles.hConnectionStatus, 'String', 'CONNECTION STATUS: ACTIVE');
        set(LiveHandles.hConnectionStatus, 'BackgroundColor', [0.5 0.9 0.5]); % Green
    else
        set(LiveHandles.hConnectionStatus, 'String', 'CONNECTION STATUS: DISCONNECTED');
        set(LiveHandles.hConnectionStatus, 'BackgroundColor', [0.9 0.5 0.5]); % Red
    end
end

try
    % First, check if we have a valid serial object
    if ~KoradConnectionStatus || isempty(SerialObj)
        % Update text controls with "disconnected" message
        if isfield(LiveHandles, 'hText') && ishandle(LiveHandles.hText)
            set(LiveHandles.hText, 'String', 'Device disconnected.\nUse option "r" to reconnect.');
        end
        
        if isfield(LiveHandles, 'hSettingsText') && ishandle(LiveHandles.hSettingsText)
            set(LiveHandles.hSettingsText, 'String', 'Settings:\nDevice disconnected.');
        end
        
        % If we have data in the arrays, still display it
        if ~isempty(tArray) && ~isempty(voltageArray) && isfield(LiveHandles, 'hOsc') && ishandle(LiveHandles.hOsc)
            tNow = now;
            % Convert time to seconds relative to tNow (newest = 0 s)
            tSec = (tArray - tNow) * 24 * 3600;
            plot(LiveHandles.hOsc, tSec, voltageArray, '-o');
            xlabel(LiveHandles.hOsc, 'Time (s) relative to now');
            ylabel(LiveHandles.hOsc, 'Voltage (V)');
            title(LiveHandles.hOsc, 'Live Voltage Trace (DISCONNECTED)');
            set(LiveHandles.hOsc, 'XDir', 'reverse');
            grid(LiveHandles.hOsc, 'on');
        end
        return;
    end
    
    % Only proceed with device communication if connected
    % Query measured voltage
    write(SerialObj, "VOUT1?", "string");
    pause(0.1);
    if SerialObj.NumBytesAvailable > 0
        voltageStr = read(SerialObj, SerialObj.NumBytesAvailable, "string");
        voltage = str2double(strtrim(voltageStr));
    else
        voltage = NaN;
    end

    % Query measured current
    write(SerialObj, "IOUT1?", "string");
    pause(0.1);
    if SerialObj.NumBytesAvailable > 0
        currentStr = read(SerialObj, SerialObj.NumBytesAvailable, "string");
        current = str2double(strtrim(currentStr));
    else
        current = NaN;
    end

    % Compute resistance (R = V/I) if possible
    if ~isnan(voltage) && ~isnan(current) && current ~= 0
        resistance = voltage / current;
    else
        resistance = NaN;
    end

    % Query voltage setting
    flush(SerialObj);
    write(SerialObj, "VSET1?", "string");
    pause(0.1);
    if SerialObj.NumBytesAvailable > 0
        vsetStr = read(SerialObj, SerialObj.NumBytesAvailable, "string");
        vset = str2double(strtrim(vsetStr));
    else
        vset = NaN;
    end
    
    % Query current setting
    flush(SerialObj);
    write(SerialObj, "ISET1?", "string");
    pause(0.1);
    if SerialObj.NumBytesAvailable > 0
        isetStr = read(SerialObj, SerialObj.NumBytesAvailable, "string");
        iset = str2double(strtrim(isetStr));
    else
        iset = NaN;
    end

    % Update main text control with measured values
    tStr = sprintf('Measured:\nVoltage: %.2f V\nCurrent: %.2f A\nResistance: %.2f Ohm', voltage, current, resistance);
    if isfield(LiveHandles, 'hText') && ishandle(LiveHandles.hText)
        set(LiveHandles.hText, 'String', tStr);
    end
    
    % Update settings text control with set values
    setStr = sprintf('Settings:\nVoltage: %.2f V\nCurrent: %.3f A', vset, iset);
    if isfield(LiveHandles, 'hSettingsText') && ishandle(LiveHandles.hSettingsText)
        set(LiveHandles.hSettingsText, 'String', setStr);
    end

    % Update persistent data arrays
    tNow = now;
    tArray = [tArray; tNow];
    voltageArray = [voltageArray; voltage];

    % Keep only the last 60 seconds of data
    timeWindow = 60 / (24*3600); % 60 seconds in days
    idx = tArray > (tNow - timeWindow);
    tArray = tArray(idx);
    voltageArray = voltageArray(idx);

    % Convert time to seconds relative to tNow (newest = 0 s)
    tSec = (tArray - tNow) * 24 * 3600;
    if isfield(LiveHandles, 'hOsc') && ishandle(LiveHandles.hOsc)
        plot(LiveHandles.hOsc, tSec, voltageArray, '-o');
        xlabel(LiveHandles.hOsc, 'Time (s) relative to now');
        ylabel(LiveHandles.hOsc, 'Voltage (V)');
        title(LiveHandles.hOsc, 'Live Voltage Trace');
        set(LiveHandles.hOsc, 'XDir', 'reverse');
        grid(LiveHandles.hOsc, 'on');
    end

catch ME
    disp(['Live update error: ', ME.message]);
    
    % If we get a connection error, update the connection status
    if contains(ME.message, 'connected to the serial port') || ...
       contains(ME.message, 'connection') || ...
       contains(ME.message, 'timeout')
        KoradConnectionStatus = false;
        if isfield(LiveHandles, 'hConnectionStatus') && ishandle(LiveHandles.hConnectionStatus)
            set(LiveHandles.hConnectionStatus, 'String', 'CONNECTION STATUS: DISCONNECTED');
            set(LiveHandles.hConnectionStatus, 'BackgroundColor', [0.9 0.5 0.5]); % Red
        end
    end
end

end