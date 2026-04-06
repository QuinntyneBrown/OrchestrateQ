function Invoke-ClaudeAgent {
    <#
    .SYNOPSIS
        Dispatches a prompt to the Claude CLI and returns the text response.
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

    $exe = if ($Agent.ExecutablePath) { $Agent.ExecutablePath } else { 'claude' }

    $argList = @()

    # Merge default + call-time parameters
    $merged = @{} + $Agent.DefaultParameters
    foreach ($k in $Parameters.Keys) { $merged[$k] = $Parameters[$k] }

    foreach ($k in $merged.Keys) {
        $argList += "--$k"
        if ($merged[$k] -isnot [bool]) {
            $argList += $merged[$k]
        }
    }

    # Prompt is passed via -p flag
    $argList += '-p'
    $argList += $Prompt

    Write-OrchestrateQLog "Claude: $exe $($argList -join ' ')" -Level DEBUG

    $output = & $exe @argList 2>&1
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Claude exited with code ${LASTEXITCODE}: $output"
    }

    return ($output | Out-String).Trim()
}
