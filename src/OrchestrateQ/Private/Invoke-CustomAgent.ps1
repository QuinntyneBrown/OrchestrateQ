function Invoke-CustomAgent {
    <#
    .SYNOPSIS
        Dispatches a prompt to a user-defined executable agent.

    .DESCRIPTION
        The prompt is passed as the final positional argument.
        Any key/value pairs in Parameters are passed as --key value flags.
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

    if (-not $Agent.ExecutablePath) {
        throw "Custom agent '$($Agent.Name)' does not have an ExecutablePath configured."
    }

    $exe = $Agent.ExecutablePath

    $merged = @{} + $Agent.DefaultParameters
    foreach ($k in $Parameters.Keys) { $merged[$k] = $Parameters[$k] }

    $argList = @()
    foreach ($k in $merged.Keys) {
        $argList += "--$k"
        if ($merged[$k] -isnot [bool]) {
            $argList += $merged[$k]
        }
    }

    $argList += $Prompt

    Write-OrchestrateQLog "Custom[$($Agent.Name)]: $exe $($argList -join ' ')" -Level DEBUG

    $LASTEXITCODE = 0
    $output = & $exe @argList 2>&1
    if ($LASTEXITCODE -gt 0) {
        throw "Custom agent '$($Agent.Name)' exited with code ${LASTEXITCODE}: $output"
    }

    return ($output | Out-String).Trim()
}
