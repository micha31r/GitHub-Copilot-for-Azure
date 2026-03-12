# thinking-log.ps1 — Unified Copilot CLI hook logger
# Writes to summary.log (compact) and detailed.jsonl (full JSON)
# Each CLI session gets its own logs/<session-id>/ directory
# PASSIVE OBSERVER: No stdout output, silent failures, always exit 0

try {
    $event = $env:HOOK_EVENT
    if (-not $event) { exit 0 }

    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }

    $hookData = $raw | ConvertFrom-Json
    $tsMs = $hookData.timestamp
    $cwd = $hookData.cwd

    # Convert epoch ms to time string
    $timeStr = if ($tsMs) {
        ([DateTimeOffset]::FromUnixTimeMilliseconds($tsMs)).ToString("HH:mm:ss.fff")
    } else {
        (Get-Date).ToString("HH:mm:ss.fff")
    }
    $isoStr = if ($tsMs) {
        ([DateTimeOffset]::FromUnixTimeMilliseconds($tsMs)).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    } else {
        (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }

    # --- Per-session log directory via parent PID ---
    $baseLogDir = "logs"
    if (-not (Test-Path $baseLogDir)) { New-Item -ItemType Directory -Path $baseLogDir -Force | Out-Null }

    # Use parent PID directly as folder name — same CLI chat process = same folder
    # All events with the same PPID append to the same folder (no archiving)
    $ppid = try { (Get-Process -Id $PID).Parent.Id } catch { $PID }
    $logDir = "$baseLogDir/$ppid"

    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    $summaryFile = "$logDir/summary.log"
    $detailedFile = "$logDir/detailed.jsonl"

    # --- Helper: truncate string (tripled limits) ---
    function Truncate([string]$s, [int]$max = 240) {
        if (-not $s) { return "" }
        $s = $s -replace "`r?`n", '\n'
        if ($s.Length -le $max) { return $s }
        return $s.Substring(0, $max) + "..."
    }

    # --- Helper: safely parse toolArgs JSON string ---
    function ParseToolArgs([string]$argsStr) {
        if (-not $argsStr) { return $null }
        try { return $argsStr | ConvertFrom-Json } catch { return $null }
    }

    # --- Helper: detect and copy temp files from tool results ---
    function CopyTempFile([string]$resultText, [string]$toolName, [string]$targetDir) {
        if (-not $resultText) { return }
        # Match patterns like "Saved to: C:\Users\...\Temp\..." or "Output too large... Saved to: ..."
        $matches = [regex]::Matches($resultText, 'Saved to:\s*([^\s\n\r"]+)')
        $counter = 0
        foreach ($m in $matches) {
            $srcPath = $m.Groups[1].Value
            if (Test-Path $srcPath -ErrorAction SilentlyContinue) {
                $ext = [System.IO.Path]::GetExtension($srcPath)
                if (-not $ext) { $ext = ".txt" }
                $counter++
                $destName = "temp-${toolName}-${counter}${ext}"
                Copy-Item -Path $srcPath -Destination "$targetDir/$destName" -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # --- Build summary line and detailed entry per event type ---
    $summaryLine = ""
    $detailedObj = @{ event = $event; ts = $isoStr; tsMs = $tsMs; ppid = $ppid }

    switch ($event) {
        "sessionStart" {
            $src = $hookData.source
            $summaryLine = "[$timeStr] SESSION>  src=$src cwd=$cwd ppid=$ppid"
            $detailedObj["source"] = $src
            $detailedObj["cwd"] = $cwd
            $detailedObj["initialPrompt"] = $hookData.initialPrompt
        }
        "sessionEnd" {
            $reason = $hookData.reason
            $summaryLine = "[$timeStr] SESSION<  reason=$reason"
            $detailedObj["reason"] = $reason
            $detailedObj["cwd"] = $cwd
        }
        "userPromptSubmitted" {
            $prompt = $hookData.prompt
            $preview = Truncate $prompt 180
            $len = if ($prompt) { $prompt.Length } else { 0 }
            $summaryLine = "[$timeStr] PROMPT    `"$preview`" ($len chars)"
            $detailedObj["prompt"] = $prompt
            $detailedObj["cwd"] = $cwd
        }
        "preToolUse" {
            $toolName = $hookData.toolName
            $argsRaw = $hookData.toolArgs
            $parsedArgs = ParseToolArgs $argsRaw
            $detail = ""
            $meta = @{}

            switch -Regex ($toolName) {
                "^(bash|powershell)$" {
                    $cmd = if ($parsedArgs) { $parsedArgs.command } else { "" }
                    $detail = "cmd: $(Truncate $cmd 210)"
                }
                "^task$" {
                    $agentType = if ($parsedArgs) { $parsedArgs.agent_type } else { "?" }
                    $mode = if ($parsedArgs) { $parsedArgs.mode } else { "sync" }
                    $desc = if ($parsedArgs) { $parsedArgs.description } else { "" }
                    $taskPrompt = if ($parsedArgs) { $parsedArgs.prompt } else { "" }
                    $modeShort = if ($mode -eq "background") { "bg" } else { "sync" }
                    $parts = @("agent:$agentType", "mode:$modeShort")
                    if ($desc) { $parts += "desc:`"$(Truncate $desc 90)`"" }
                    if ($taskPrompt) { $parts += "prompt:`"$(Truncate $taskPrompt 120)`"" }
                    $detail = $parts -join " "
                }
                "^skill$" {
                    $skillName = if ($parsedArgs) { $parsedArgs.skill } else { "?" }
                    $detail = "name:$skillName"
                    $meta = @{ isSkill = $true; skillName = $skillName }
                }
                "^(edit|create|view)$" {
                    $filePath = if ($parsedArgs) { $parsedArgs.path } else { "" }
                    $detail = "path:$(Truncate $filePath 210)"
                }
                "^(grep|glob)$" {
                    $pattern = if ($parsedArgs) { $parsedArgs.pattern } else { "" }
                    $filePath = if ($parsedArgs) { $parsedArgs.path } else { "" }
                    $detail = "pattern:`"$(Truncate $pattern 120)`""
                    if ($filePath) { $detail += " path:$filePath" }
                }
                default {
                    if ($parsedArgs) {
                        $firstKey = ($parsedArgs.PSObject.Properties | Select-Object -First 1).Name
                        $firstVal = ($parsedArgs.PSObject.Properties | Select-Object -First 1).Value
                        if ($firstKey -and $firstVal) {
                            $detail = "$firstKey`:`"$(Truncate "$firstVal" 150)`""
                        }
                    }
                }
            }

            $toolPad = $toolName.PadRight(18)
            $summaryLine = "[$timeStr] TOOL>     $toolPad| $detail"

            $detailedObj["toolName"] = $toolName
            if ($parsedArgs) { $detailedObj["toolArgs"] = $parsedArgs } else { $detailedObj["toolArgsRaw"] = $argsRaw }
            if ($meta.Count -gt 0) { $detailedObj["meta"] = $meta }
        }
        "postToolUse" {
            $toolName = $hookData.toolName
            $argsRaw = $hookData.toolArgs
            $parsedArgs = ParseToolArgs $argsRaw
            $resultType = $hookData.toolResult.resultType
            $resultText = $hookData.toolResult.textResultForLlm

            $statusIcon = switch ($resultType) {
                "success" { [char]0x2713 }  # ✓
                "failure" { [char]0x2717 }  # ✗
                "denied"  { [char]0x26D4 }  # ⛔
                default   { "?" }
            }

            $detail = ""
            if ($toolName -eq "task" -and $parsedArgs) {
                $agentType = $parsedArgs.agent_type
                if ($agentType) { $detail = "agent:$agentType" }
            }
            if ($resultText) {
                $preview = Truncate $resultText 180
                if ($detail) { $detail += " " }
                $detail += "`"$preview`""
            }

            $toolPad = $toolName.PadRight(18)
            $statusPad = "$statusIcon".PadRight(5)
            $summaryLine = "[$timeStr] TOOL<     $toolPad$statusPad| $detail"

            # Copy any temp files referenced in the result
            CopyTempFile $resultText $toolName $logDir

            $detailedObj["toolName"] = $toolName
            if ($parsedArgs) { $detailedObj["toolArgs"] = $parsedArgs } else { $detailedObj["toolArgsRaw"] = $argsRaw }
            $detailedObj["result"] = @{ type = $resultType; text = $resultText }
        }
        "agentStop" {
            $summaryLine = "[$timeStr] AGENT<    complete"
            $detailedObj["cwd"] = $cwd
        }
        "subagentStop" {
            $summaryLine = "[$timeStr] SUBAGENT< complete"
            $detailedObj["cwd"] = $cwd
        }
        "errorOccurred" {
            $errMsg = $hookData.error.message
            $errName = $hookData.error.name
            $preview = Truncate $errMsg 180
            $namePad = if ($errName) { $errName.PadRight(18) } else { "UnknownError".PadRight(18) }
            $summaryLine = "[$timeStr] ERROR     $namePad| `"$preview`""

            $detailedObj["error"] = @{
                name = $errName
                message = $errMsg
                stack = $hookData.error.stack
            }
        }
    }

    # --- Write logs ---
    if ($summaryLine) {
        Add-Content -Path $summaryFile -Value $summaryLine -Encoding UTF8
    }
    $detailedJson = $detailedObj | ConvertTo-Json -Compress -Depth 5
    Add-Content -Path $detailedFile -Value $detailedJson -Encoding UTF8

} catch {
    # Silent failure — never affect the agent
}
exit 0
