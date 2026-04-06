function Invoke-CodexAgent {
    <#
    .SYNOPSIS
        Dispatches a prompt to OpenAI Codex / the `codex` CLI and returns the response.

    .DESCRIPTION
        Supports both the official `codex` CLI tool and the `openai` CLI.
        Requires OPENAI_API_KEY to be set (or passed via agent parameters).
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

    $exe = if ($Agent.ExecutablePath) { $Agent.ExecutablePath } else { 'codex' }

    $merged = @{} + $Agent.DefaultParameters
    foreach ($k in $Parameters.Keys) { $merged[$k] = $Parameters[$k] }

    $argList = @()
    foreach ($k in $merged.Keys) {
        if ($k -ne 'api_key') {
            $argList += "--$k"
            if ($merged[$k] -isnot [bool]) {
                $argList += $merged[$k]
            }
        }
    }

    $argList += $Prompt

    Write-OrchestrateQLog "Codex: $exe $($argList -join ' ')" -Level DEBUG

    $LASTEXITCODE = 0
    $output = & $exe @argList 2>&1
    if ($LASTEXITCODE -gt 0) {
        throw "Codex exited with code ${LASTEXITCODE}: $output"
    }

    return ($output | Out-String).Trim()
}
