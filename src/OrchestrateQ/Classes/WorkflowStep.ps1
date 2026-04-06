enum StepExecutionMode {
    Sequential
    Parallel
}

class WorkflowStep {
    [string]           $Name
    [string]           $AgentName
    [string]           $PromptTemplate
    [string[]]         $DependsOn
    [hashtable]        $Parameters
    [StepExecutionMode] $ExecutionMode
    [int]              $MaxRetries
    [int]              $TimeoutSeconds
    [scriptblock]      $OnSuccess
    [scriptblock]      $OnFailure

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

    [string] ToString() {
        return "WorkflowStep[$($this.Name) -> $($this.AgentName)]"
    }
}
