function Invoke-AIAgent {
    <#
    .SYNOPSIS
        Sends a prompt directly to a registered AI agent and returns its response.

    .PARAMETER Name
        The name of a registered agent to use.

    .PARAMETER Type
        When -Name is not provided, use a temporary agent of this type.

    .PARAMETER Prompt
        The prompt text to send to the agent.

    .PARAMETER Parameters
        Additional parameters to pass to the agent for this call, overriding defaults.

    .PARAMETER MaxRetries
        Number of times to retry on failure (default: 0).

    .PARAMETER RetryDelaySeconds
        Seconds to wait between retries (default: 5).

    .EXAMPLE
        Invoke-AIAgent -Name "Claude" -Prompt "Write hello world in Python"

    .EXAMPLE
        Invoke-AIAgent -Type Gemini -Prompt "Explain quantum computing"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ParameterSetName = 'ByType', Mandatory)]
        [AIAgentType] $Type,

        [Parameter(ParameterSetName = 'ByType')]
        [string] $ExecutablePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Prompt,

        [Parameter()]
        [hashtable] $Parameters = @{},

        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $MaxRetries = 0,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int] $RetryDelaySeconds = 5
    )

    # Resolve the agent
    $agent = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        if (-not $script:AgentRegistry.ContainsKey($Name)) {
            throw "No agent named '$Name' is registered.  Run Register-AIAgent first."
        }
        $script:AgentRegistry[$Name]
    }
    else {
        $a = [AIAgent]::new("__temp__$Type", $Type)
        if ($ExecutablePath) { $a.ExecutablePath = $ExecutablePath }
        $a
    }

    $attempt = 0
    do {
        try {
            Write-OrchestrateQLog "Invoking agent '$($agent.Name)' (attempt $($attempt + 1))"
            $response = Invoke-AgentDispatch -Agent $agent -Prompt $Prompt -Parameters $Parameters
            return $response
        }
        catch {
            $attempt++
            if ($attempt -le $MaxRetries) {
                Write-OrchestrateQLog "Agent '$($agent.Name)' failed (attempt $attempt): $_. Retrying in ${RetryDelaySeconds}s..." -Level WARN
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw
            }
        }
    } while ($attempt -le $MaxRetries)
}
