function Import-Workflow {
    <#
    .SYNOPSIS
        Loads a workflow from a JSON file exported by Export-Workflow.

    .PARAMETER Path
        Path to the JSON file.

    .PARAMETER Force
        Overwrite an existing workflow with the same name in the registry.

    .EXAMPLE
        Import-Workflow -Path ".\workflows\CodeReview.json"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('Workflow')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [switch] $Force
    )

    process {
        if (-not (Test-Path $Path)) {
            throw "File not found: '$Path'"
        }

        $raw = Get-Content -Path $Path -Raw -Encoding utf8 | ConvertFrom-Json

        $wfName = $raw.Name

        if ($script:WorkflowRegistry.ContainsKey($wfName) -and -not $Force) {
            throw "A workflow named '$wfName' already exists.  Use -Force to overwrite."
        }

        if (-not $PSCmdlet.ShouldProcess($Path, 'Import Workflow')) { return }

        $wf             = [Workflow]::new($wfName)
        $wf.Description = $raw.Description
        $wf.LogPath     = $raw.LogPath

        # Restore variables
        if ($raw.Variables) {
            $raw.Variables.PSObject.Properties | ForEach-Object {
                $wf.Variables[$_.Name] = $_.Value
            }
        }

        # Restore steps
        foreach ($s in $raw.Steps) {
            $step                = [WorkflowStep]::new()
            $step.Name           = $s.Name
            $step.AgentName      = $s.AgentName
            $step.PromptTemplate = $s.PromptTemplate
            $step.DependsOn      = if ($s.DependsOn) { @($s.DependsOn) } else { @() }
            $step.MaxRetries     = $s.MaxRetries
            $step.TimeoutSeconds = $s.TimeoutSeconds

            if ($s.Parameters) {
                $s.Parameters.PSObject.Properties | ForEach-Object {
                    $step.Parameters[$_.Name] = $_.Value
                }
            }

            $step.ExecutionMode = if ($s.ExecutionMode -eq 'Parallel') {
                [StepExecutionMode]::Parallel
            }
            else {
                [StepExecutionMode]::Sequential
            }

            $wf.AddStep($step)
        }

        $script:WorkflowRegistry[$wfName] = $wf
        Write-OrchestrateQLog "Imported workflow '$wfName' from '$Path' ($($wf.Steps.Count) step(s))"
        return $wf
    }
}
