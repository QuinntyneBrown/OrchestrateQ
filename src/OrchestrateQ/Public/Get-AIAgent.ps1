function Get-AIAgent {
    <#
    .SYNOPSIS
        Retrieves one or all registered AI agents.

    .PARAMETER Name
        The name of the agent to retrieve.  When omitted, all agents are returned.

    .EXAMPLE
        Get-AIAgent

    .EXAMPLE
        Get-AIAgent -Name "Claude"
    #>
    [CmdletBinding()]
    [OutputType('AIAgent')]
    param(
        [Parameter(Position = 0)]
        [string] $Name
    )

    if ($Name) {
        if (-not $script:AgentRegistry.ContainsKey($Name)) {
            throw "No agent named '$Name' is registered."
        }
        return $script:AgentRegistry[$Name]
    }

    return $script:AgentRegistry.Values
}
