function Add-WorkflowStep {
    <#
    .SYNOPSIS
        Adds an AI-agent step to an existing workflow.

    .PARAMETER Workflow
        The Workflow object (returned by New-Workflow) to add the step to.

    .PARAMETER WorkflowName
        Alternative to -Workflow: specify the workflow by name.

    .PARAMETER Name
        A unique name for this step within the workflow.

    .PARAMETER AgentName
        The name of a registered agent to use for this step.

    .PARAMETER PromptTemplate
        The prompt sent to the agent.  Supports template tokens:
          {Input}            - the original workflow input
          {PreviousOutput}   - the last completed step's output
          {StepName.Output}  - a specific step's output
          {Variable.Key}     - a workflow variable

    .PARAMETER DependsOn
        Names of steps that must complete before this step runs.

    .PARAMETER Parameters
        Additional agent parameters for this step.

    .PARAMETER Parallel
        Mark this step to run in parallel with other parallel-flagged steps.

    .PARAMETER MaxRetries
        Retry this step up to N times on failure (default: 0).

    .PARAMETER TimeoutSeconds
        Maximum seconds to wait for the agent response (default: 120).

    .PARAMETER OnSuccess
        Script block executed after a successful step.  Receives $StepResult.

    .PARAMETER OnFailure
        Script block executed after a failed step.  Receives $StepResult.

    .EXAMPLE
        $wf | Add-WorkflowStep -Name "Analyze" -AgentName "Claude" `
            -PromptTemplate "Analyze this code:\n{Input}"

    .EXAMPLE
        Add-WorkflowStep -WorkflowName "CodeReview" -Name "Suggest" `
            -AgentName "Gemini" `
            -PromptTemplate "Suggest improvements based on:\n{Analyze.Output}" `
            -DependsOn "Analyze"
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByObject')]
    [OutputType('WorkflowStep')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByObject', ValueFromPipeline, Position = 0)]
        [Workflow] $Workflow,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string] $WorkflowName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AgentName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PromptTemplate,

        [Parameter()]
        [string[]] $DependsOn = @(),

        [Parameter()]
        [hashtable] $Parameters = @{},

        [Parameter()]
        [switch] $Parallel,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $MaxRetries = 0,

        [Parameter()]
        [ValidateRange(1, 3600)]
        [int] $TimeoutSeconds = 120,

        [Parameter()]
        [scriptblock] $OnSuccess,

        [Parameter()]
        [scriptblock] $OnFailure
    )

    process {
        $target = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            if (-not $script:WorkflowRegistry.ContainsKey($WorkflowName)) {
                throw "No workflow named '$WorkflowName' found."
            }
            $script:WorkflowRegistry[$WorkflowName]
        }
        else { $Workflow }

        # Ensure step name is unique within the workflow
        if ($target.Steps | Where-Object { $_.Name -eq $Name }) {
            throw "Workflow '$($target.Name)' already has a step named '$Name'."
        }

        if ($PSCmdlet.ShouldProcess("$($target.Name)/$Name", 'Add Workflow Step')) {
            $step                  = [WorkflowStep]::new($Name, $AgentName, $PromptTemplate)
            $step.DependsOn        = $DependsOn
            $step.Parameters       = $Parameters
            $step.ExecutionMode    = if ($Parallel) { [StepExecutionMode]::Parallel } else { [StepExecutionMode]::Sequential }
            $step.MaxRetries       = $MaxRetries
            $step.TimeoutSeconds   = $TimeoutSeconds
            $step.OnSuccess        = $OnSuccess
            $step.OnFailure        = $OnFailure

            $target.AddStep($step)

            Write-OrchestrateQLog "Added step '$Name' to workflow '$($target.Name)'"
            return $step
        }
    }
}
