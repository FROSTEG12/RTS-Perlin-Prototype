param([Parameter(Mandatory)][int]$TargetProcessId, [Parameter(Mandatory)][string]$OutputPrefix)
$threads = (Get-CimInstance Win32_Processor | Measure-Object NumberOfLogicalProcessors -Sum).Sum
$writer = [System.IO.StreamWriter]::new($outputPrefix + '-os.jsonl', $false)
$lastCpu = $null
$lastTime = [DateTime]::UtcNow
try {
    while ($true) {
        $process = Get-Process -Id $TargetProcessId -ErrorAction SilentlyContinue
        if (-not $process) { break }
        $now = [DateTime]::UtcNow
        $cpu = $process.TotalProcessorTime.TotalSeconds
        $percent = $null
        if ($null -ne $lastCpu) { $percent = 100 * ($cpu - $lastCpu) / (($now - $lastTime).TotalSeconds * $threads) }
        $lastCpu = $cpu
        $lastTime = $now
        $status = $null
        try { $status = Get-Content ($outputPrefix + '-status.json') -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
        $gpu = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -Filter "Name LIKE 'pid_${TargetProcessId}_%engtype_3D%'" -ErrorAction SilentlyContinue
        $gpuUtil = $null
        if ($gpu) { $gpuUtil = ($gpu | Measure-Object UtilizationPercentage -Sum).Sum }
        $sample = [ordered]@{ unix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()/1000; pid = $TargetProcessId; phase = $status.phase; units = $status.units; cpu_total_percent = $percent; gpu_3d_percent = $gpuUtil; working_set_mib = $process.WorkingSet64/1MB; private_mib = $process.PrivateMemorySize64/1MB }
        $writer.WriteLine(($sample | ConvertTo-Json -Compress))
        $writer.Flush()
        Start-Sleep -Seconds 1
    }
} finally { $writer.Dispose() }
