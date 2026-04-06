enum AIAgentType {
    Claude
    Gemini
    Copilot
    Codex
    Custom
}

class AIAgent {
    [string]    $Name
    [AIAgentType] $Type
    [string]    $ExecutablePath
    [hashtable] $DefaultParameters
    [bool]      $IsAvailable

    AIAgent() {
        $this.DefaultParameters = @{}
        $this.IsAvailable = $false
    }

    AIAgent([string]$name, [AIAgentType]$type) {
        $this.Name             = $name
        $this.Type             = $type
        $this.DefaultParameters = @{}
        $this.IsAvailable      = $false
    }

    [string] ToString() {
        return "AIAgent[$($this.Name), $($this.Type)]"
    }
}
