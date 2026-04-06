function Invoke-CopilotAgent {
    <#
    .SYNOPSIS
        Dispatches a prompt to GitHub Copilot CLI via `gh copilot suggest`.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AIAgent] $Agent,

        [Parameter(Mandatory)]
        [string] $Prompt,

        [hashtable] $Parameters = @{}
    )

    $exe = if ($Agent.ExecutablePath) { $Agent.ExecutablePath } else { 'gh' }

    $merged = @{} + $Agent.DefaultParameters
    foreach ($k in $Parameters.Keys) { $merged[$k] = $Parameters[$k] }

    # Default target for gh copilot is 'shell' unless overridden
    $target = if ($merged.ContainsKey('target')) { $merged['target'] } else { 'shell' }

    $argList = @('copilot', 'suggest', '-t', $target)

    foreach ($k in $merged.Keys) {
        if ($k -notin @('target')) {
            $argList += "--$k"
            if ($merged[$k] -isnot [bool]) {
                $argList += $merged[$k]
            }
        }
    }

    $argList += $Prompt

    Write-OrchestrateQLog "Copilot: $exe $($argList -join ' ')" -Level DEBUG

    $output = & $exe @argList 2>&1
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "GitHub Copilot CLI exited with code ${LASTEXITCODE}: $output"
    }

    return ($output | Out-String).Trim()
}
