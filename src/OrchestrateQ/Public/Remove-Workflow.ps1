function Remove-Workflow {
    <#
    .SYNOPSIS
        Removes a registered workflow.

    .PARAMETER Name
        The name of the workflow to remove.

    .EXAMPLE
        Remove-Workflow -Name "CodeReview"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    process {
        if (-not $script:WorkflowRegistry.ContainsKey($Name)) {
            throw "No workflow named '$Name' is registered."
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Remove Workflow')) {
            $script:WorkflowRegistry.Remove($Name)
            Write-OrchestrateQLog "Removed workflow '$Name'"
        }
    }
}
