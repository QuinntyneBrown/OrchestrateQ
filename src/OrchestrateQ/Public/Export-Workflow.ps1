function Export-Workflow {
    <#
    .SYNOPSIS
        Serializes a workflow to a JSON file for portability and version control.

    .PARAMETER Name
        The name of the workflow to export.

    .PARAMETER Workflow
        The Workflow object to export.

    .PARAMETER Path
        Destination file path (default: .\<WorkflowName>.workflow.json).

    .PARAMETER Force
        Overwrite an existing file at -Path.

    .EXAMPLE
        Export-Workflow -Name "CodeReview" -Path ".\workflows\CodeReview.json"

    .EXAMPLE
        Get-Workflow | Export-Workflow -Path ".\all-workflows.json"
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, ParameterSetName = 'ByObject', ValueFromPipeline)]
        [Workflow] $Workflow,

        [Parameter(Position = 1)]
        [string] $Path,

        [Parameter()]
        [switch] $Force
    )

    process {
        $wf = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            if (-not $script:WorkflowRegistry.ContainsKey($Name)) {
                throw "No workflow named '$Name' is registered."
            }
            $script:WorkflowRegistry[$Name]
        }
        else { $Workflow }

        $destPath = if ($Path) { $Path } else { ".\$($wf.Name).workflow.json" }

        if ((Test-Path $destPath) -and -not $Force) {
            throw "File '$destPath' already exists.  Use -Force to overwrite."
        }

        $dto = @{
            Name        = $wf.Name
            Description = $wf.Description
            Variables   = $wf.Variables
            LogPath     = $wf.LogPath
            CreatedAt   = $wf.CreatedAt.ToString('o')
            Steps       = @(
                $wf.Steps | ForEach-Object {
                    @{
                        Name           = $_.Name
                        AgentName      = $_.AgentName
                        PromptTemplate = $_.PromptTemplate
                        DependsOn      = $_.DependsOn
                        Parameters     = $_.Parameters
                        ExecutionMode  = $_.ExecutionMode.ToString()
                        MaxRetries     = $_.MaxRetries
                        TimeoutSeconds = $_.TimeoutSeconds
                    }
                }
            )
        }

        if ($PSCmdlet.ShouldProcess($destPath, 'Export Workflow')) {
            $dto | ConvertTo-Json -Depth 10 | Set-Content -Path $destPath -Encoding utf8 -Force:$Force
            Write-OrchestrateQLog "Exported workflow '$($wf.Name)' to '$destPath'"
        }
    }
}
