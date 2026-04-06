function New-Workflow {
    <#
    .SYNOPSIS
        Creates a new named workflow.

    .PARAMETER Name
        A unique name for the workflow.

    .PARAMETER Description
        An optional human-readable description.

    .PARAMETER Variables
        A hashtable of workflow-level variables available in step prompt templates.

    .PARAMETER LogPath
        Optional path to a log file where execution events will be written.

    .PARAMETER Force
        Overwrite an existing workflow with the same name.

    .EXAMPLE
        $wf = New-Workflow -Name "CodeReview" -Description "Review and improve code"

    .EXAMPLE
        New-Workflow -Name "Research" -Variables @{ Language = "Python" }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('Workflow')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Position = 1)]
        [string] $Description,

        [Parameter()]
        [hashtable] $Variables = @{},

        [Parameter()]
        [string] $LogPath,

        [Parameter()]
        [switch] $Force
    )

    if ($script:WorkflowRegistry.ContainsKey($Name) -and -not $Force) {
        throw "A workflow named '$Name' already exists.  Use -Force to overwrite."
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create Workflow')) {
        $workflow             = [Workflow]::new($Name, $Description)
        $workflow.Variables   = $Variables
        $workflow.LogPath     = $LogPath

        $script:WorkflowRegistry[$Name] = $workflow

        Write-OrchestrateQLog "Created workflow '$Name'"
        return $workflow
    }
}
