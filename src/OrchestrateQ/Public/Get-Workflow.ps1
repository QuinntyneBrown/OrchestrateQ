function Get-Workflow {
    <#
    .SYNOPSIS
        Retrieves one or all registered workflows.

    .PARAMETER Name
        The name of the workflow to retrieve.  When omitted, all workflows are returned.

    .EXAMPLE
        Get-Workflow

    .EXAMPLE
        Get-Workflow -Name "CodeReview"
    #>
    [CmdletBinding()]
    [OutputType('Workflow')]
    param(
        [Parameter(Position = 0)]
        [string] $Name
    )

    if ($Name) {
        if (-not $script:WorkflowRegistry.ContainsKey($Name)) {
            throw "No workflow named '$Name' is registered."
        }
        return $script:WorkflowRegistry[$Name]
    }

    return $script:WorkflowRegistry.Values
}
