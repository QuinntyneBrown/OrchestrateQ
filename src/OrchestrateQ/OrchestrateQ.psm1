#Requires -Version 5.1
<#
.SYNOPSIS
    OrchestrateQ — PowerShell module for orchestrating AI Agents and workflows.
#>

# -----------------------------------------------------------------------
# Classes — defined inline so they are available as type accelerators
# -----------------------------------------------------------------------

enum AIAgentType {
    Claude
    Gemini
    Copilot
    Codex
    Custom
}

class AIAgent {
    [string]      $Name
    [AIAgentType] $Type
    [string]      $ExecutablePath
    [hashtable]   $DefaultParameters
    [bool]        $IsAvailable

    AIAgent() {
        $this.DefaultParameters = @{}
        $this.IsAvailable = $false
    }

    AIAgent([string]$name, [AIAgentType]$type) {
        $this.Name              = $name
        $this.Type              = $type
        $this.DefaultParameters = @{}
        $this.IsAvailable       = $false
    }

    [string] ToString() { return "AIAgent[$($this.Name), $($this.Type)]" }
}

enum StepExecutionMode {
    Sequential
    Parallel
}

class WorkflowStep {
    [string]            $Name
    [string]            $AgentName
    [string]            $PromptTemplate
    [string[]]          $DependsOn
    [hashtable]         $Parameters
    [StepExecutionMode] $ExecutionMode
    [int]               $MaxRetries
    [int]               $TimeoutSeconds
    [scriptblock]       $OnSuccess
    [scriptblock]       $OnFailure

    WorkflowStep() {
        $this.DependsOn      = @()
        $this.Parameters     = @{}
        $this.ExecutionMode  = [StepExecutionMode]::Sequential
        $this.MaxRetries     = 0
        $this.TimeoutSeconds = 120
    }

    WorkflowStep([string]$name, [string]$agentName, [string]$promptTemplate) {
        $this.Name           = $name
        $this.AgentName      = $agentName
        $this.PromptTemplate = $promptTemplate
        $this.DependsOn      = @()
        $this.Parameters     = @{}
        $this.ExecutionMode  = [StepExecutionMode]::Sequential
        $this.MaxRetries     = 0
        $this.TimeoutSeconds = 120
    }

    [string] ToString() { return "WorkflowStep[$($this.Name) -> $($this.AgentName)]" }
}

class Workflow {
    [string]         $Name
    [string]         $Description
    [WorkflowStep[]] $Steps
    [hashtable]      $Variables
    [string]         $LogPath
    [datetime]       $CreatedAt
    [datetime]       $UpdatedAt

    Workflow() {
        $this.Steps     = @()
        $this.Variables = @{}
        $this.CreatedAt = [datetime]::UtcNow
        $this.UpdatedAt = [datetime]::UtcNow
    }

    Workflow([string]$name) {
        $this.Name      = $name
        $this.Steps     = @()
        $this.Variables = @{}
        $this.CreatedAt = [datetime]::UtcNow
        $this.UpdatedAt = [datetime]::UtcNow
    }

    Workflow([string]$name, [string]$description) {
        $this.Name        = $name
        $this.Description = $description
        $this.Steps       = @()
        $this.Variables   = @{}
        $this.CreatedAt   = [datetime]::UtcNow
        $this.UpdatedAt   = [datetime]::UtcNow
    }

    [void] AddStep([WorkflowStep]$step) {
        $this.Steps    += $step
        $this.UpdatedAt = [datetime]::UtcNow
    }

    [string] ToString() { return "Workflow[$($this.Name), Steps=$($this.Steps.Count)]" }
}

class StepResult {
    [string]   $StepName
    [bool]     $Success
    [string]   $Output
    [string]   $Error
    [int]      $RetryCount
    [datetime] $StartTime
    [datetime] $EndTime
    [timespan] $Duration

    StepResult() { $this.StartTime = [datetime]::UtcNow }

    StepResult([string]$stepName) {
        $this.StepName  = $stepName
        $this.StartTime = [datetime]::UtcNow
    }

    [void] Complete([bool]$success, [string]$output, [string]$error) {
        $this.Success  = $success
        $this.Output   = $output
        $this.Error    = $error
        $this.EndTime  = [datetime]::UtcNow
        $this.Duration = $this.EndTime - $this.StartTime
    }

    [string] ToString() {
        $status = if ($this.Success) { 'OK' } else { 'FAIL' }
        return "StepResult[$($this.StepName), $status]"
    }
}

class WorkflowResult {
    [string]       $WorkflowName
    [bool]         $Success
    [string]       $Output
    [string[]]     $Errors
    [StepResult[]] $StepResults
    [datetime]     $StartTime
    [datetime]     $EndTime
    [timespan]     $Duration

    WorkflowResult() {
        $this.StepResults = @()
        $this.Errors      = @()
        $this.StartTime   = [datetime]::UtcNow
    }

    WorkflowResult([string]$workflowName) {
        $this.WorkflowName = $workflowName
        $this.StepResults  = @()
        $this.Errors       = @()
        $this.StartTime    = [datetime]::UtcNow
    }

    [void] Complete([bool]$success) {
        $this.Success  = $success
        $this.EndTime  = [datetime]::UtcNow
        $this.Duration = $this.EndTime - $this.StartTime
        $lastStep = $this.StepResults | Where-Object { $_.Success } | Select-Object -Last 1
        if ($lastStep) { $this.Output = $lastStep.Output }
    }

    [string] ToString() {
        $status = if ($this.Success) { 'OK' } else { 'FAIL' }
        return "WorkflowResult[$($this.WorkflowName), $status, Steps=$($this.StepResults.Count)]"
    }
}

# -----------------------------------------------------------------------
# Module-scoped state (case-insensitive hashtables)
# -----------------------------------------------------------------------
$script:AgentRegistry    = [hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
$script:WorkflowRegistry = [hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)

# -----------------------------------------------------------------------
# Dot-source: Private helpers
# -----------------------------------------------------------------------
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" | ForEach-Object { . $_.FullName }

# -----------------------------------------------------------------------
# Dot-source: Public cmdlets
# -----------------------------------------------------------------------
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" | ForEach-Object { . $_.FullName }
