# KORAD Power Supply Controller  

## Overview  
This project is a **MATLAB-based serial controller** for the **KORAD KA3005P DC power supply**. It enables **real-time voltage and current adjustments, status monitoring, automated voltage ramping, and memory functions** using a **fully automated serial port detection system**.  

## Features  
- **Automatic Serial Port Detection** – No need to manually specify the COM port.  
- **Voltage & Current Control** – Set and read precise voltage/current values.  
- **Power Output Control** – Turn the power supply **on/off** via software commands.  
- **Voltage Ramping** – Automate voltage adjustments over time with step-based control.  
- **Memory Functions** – Save and recall voltage/current settings from the **KORAD memory slots (M1-M5)**.  
- **Logging** – Outputs session logs to a text file for debugging and tracking.  

## How It Works  
1. **Automatically detects the correct serial port** for the KORAD PSU.  
2. **Communicates with the PSU** using MATLAB's built-in serial commands.  
3. **Reads and displays** real-time voltage, current, and output status.  
4. **Allows manual or automated control** of voltage and current settings.  
5. **Runs voltage ramps** for stepwise adjustments over a user-defined interval.  
6. **Stores logs** of all interactions in a session file for tracking and debugging.  

## Setup & Requirements  
### Hardware  
- **KORAD KA3005P DC Power Supply**  
- **PC with MATLAB installed**  
- **USB-to-Serial Connection (if needed)**  

### Software Dependencies  
- **MATLAB** (Supports Serial Communication Toolbox)  

## Usage Instructions  
1. **Ensure MATLAB is installed and configured** with serial communication support.  
2. **Connect the KORAD PSU** to your PC via USB or serial cable.  
3. **Run the script in MATLAB**—the correct COM port is automatically detected.  
4. **Use the interactive menu** to control voltage, current, and power settings.  
5. **Monitor and adjust settings** as needed for your application.  

## Command Options  
- **Read Voltage & Current** (`VOUT1?`, `IOUT1?`)  
- **Set Voltage & Current** (`VSET1:<value>`, `ISET1:<value>`)  
- **Turn Output On/Off** (`OUT1`, `OUT0`)  
- **Voltage Ramp Control** (`VSET1` in steps over time)  
- **Save/Recall Memory Slots** (`SAVx`, `RCLx`)  

## Error Handling  
- **Automatic detection ensures correct COM port selection.**  
- If the PSU is unresponsive, ensure the **device is powered on and properly connected.**  
- Logs are stored in `korad_controller_log.txt` for debugging.  

## Future Improvements  
- **Automated real-time voltage adjustments based on external sensor inputs.**  
- **Integration with additional MATLAB GUIs for easier control.**  
- **Expanded PSU compatibility beyond KORAD models.**  

## License  
This project is open-source and can be modified for research, testing, and educational purposes.  

---

This keeps it **polished, accurate, and fully reflects your improvements.** 🚀 Let me know if you'd like any more tweaks!
