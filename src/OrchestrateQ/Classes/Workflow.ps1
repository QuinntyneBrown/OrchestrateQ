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
        $this.Steps     += $step
        $this.UpdatedAt  = [datetime]::UtcNow
    }

    [string] ToString() {
        return "Workflow[$($this.Name), Steps=$($this.Steps.Count)]"
    }
}
