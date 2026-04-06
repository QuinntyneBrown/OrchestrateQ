class StepResult {
    [string]   $StepName
    [bool]     $Success
    [string]   $Output
    [string]   $Error
    [int]      $RetryCount
    [datetime] $StartTime
    [datetime] $EndTime
    [timespan] $Duration

    StepResult() {
        $this.StartTime = [datetime]::UtcNow
    }

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
    [string]      $WorkflowName
    [bool]        $Success
    [string]      $Output
    [string[]]    $Errors
    [StepResult[]] $StepResults
    [datetime]    $StartTime
    [datetime]    $EndTime
    [timespan]    $Duration

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
        if ($lastStep) {
            $this.Output = $lastStep.Output
        }
    }

    [string] ToString() {
        $status = if ($this.Success) { 'OK' } else { 'FAIL' }
        return "WorkflowResult[$($this.WorkflowName), $status, Steps=$($this.StepResults.Count)]"
    }
}
