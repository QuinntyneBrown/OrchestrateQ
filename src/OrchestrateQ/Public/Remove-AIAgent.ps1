function Remove-AIAgent {
    <#
    .SYNOPSIS
        Removes a registered AI agent from the module registry.

    .PARAMETER Name
        The name of the agent to remove.

    .EXAMPLE
        Remove-AIAgent -Name "Claude"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    process {
        if (-not $script:AgentRegistry.ContainsKey($Name)) {
            throw "No agent named '$Name' is registered."
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Remove AI Agent')) {
            $script:AgentRegistry.Remove($Name)
            Write-OrchestrateQLog "Removed agent '$Name'"
        }
    }
}
