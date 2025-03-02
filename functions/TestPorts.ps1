# Get a list of COM ports (customize as needed)
$ports = [System.IO.Ports.SerialPort]::GetPortNames()

$jobs = @()

# First, test all ports except COM8
foreach ($port in $ports | Where-Object { $_ -ne "COM8" }) {
    $jobs += Start-Job -ScriptBlock {
        param($p)
        try {
            $sp = New-Object System.IO.Ports.SerialPort $p, 9600, 'None', 8, 'One'
            $sp.ReadTimeout = 1000
            $sp.WriteTimeout = 1000
            $sp.Open()
            $sp.WriteLine("*IDN?")
            Start-Sleep -Milliseconds 500
            $response = ""
            if ($sp.BytesToRead -gt 0) {
                $response = $sp.ReadExisting()
            }
            $sp.Close()
            return @{ Port = $p; Response = $response }
        } catch {
            return @{ Port = $p; Error = $_.Exception.Message }
        }
    } -ArgumentList $port
}

# Then, if COM8 exists, test it last
if ($ports -contains "COM8") {
    $jobs += Start-Job -ScriptBlock {
        param($p)
        try {
            $sp = New-Object System.IO.Ports.SerialPort $p, 9600, 'None', 8, 'One'
            $sp.ReadTimeout = 1000
            $sp.WriteTimeout = 1000
            $sp.Open()
            $sp.WriteLine("*IDN?")
            Start-Sleep -Milliseconds 500
            $response = ""
            if ($sp.BytesToRead -gt 0) {
                $response = $sp.ReadExisting()
            }
            $sp.Close()
            return @{ Port = $p; Response = $response }
        } catch {
            return @{ Port = $p; Error = $_.Exception.Message }
        }
    } -ArgumentList "COM8"
}

# Wait for all jobs to finish
Wait-Job -Job $jobs

# Collect all results and output them as JSON
$results = $jobs | ForEach-Object { Receive-Job -Job $_ }
$results | ConvertTo-Json
