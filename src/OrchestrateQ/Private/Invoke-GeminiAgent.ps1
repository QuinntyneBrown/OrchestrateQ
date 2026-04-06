function Invoke-GeminiAgent {
    <#
    .SYNOPSIS
        Dispatches a prompt to the Gemini CLI and returns the text response.
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

    $exe = if ($Agent.ExecutablePath) { $Agent.ExecutablePath } else { 'gemini' }

    $merged = @{} + $Agent.DefaultParameters
    foreach ($k in $Parameters.Keys) { $merged[$k] = $Parameters[$k] }

    $argList = @()
    foreach ($k in $merged.Keys) {
        $argList += "--$k"
        if ($merged[$k] -isnot [bool]) {
            $argList += $merged[$k]
        }
    }

    # Prompt is passed as a positional argument
    $argList += $Prompt

    Write-OrchestrateQLog "Gemini: $exe $($argList -join ' ')" -Level DEBUG

    $LASTEXITCODE = 0
    $output = & $exe @argList 2>&1
    if ($LASTEXITCODE -gt 0) {
        throw "Gemini exited with code ${LASTEXITCODE}: $output"
    }

    return ($output | Out-String).Trim()
}
