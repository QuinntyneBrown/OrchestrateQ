#Requires -Module Pester
#Requires -Version 5.1
<#
.SYNOPSIS
    Pester tests for the OrchestrateQ module.
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'src' 'OrchestrateQ' 'OrchestrateQ.psd1'
    Import-Module $ModulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module OrchestrateQ -ErrorAction SilentlyContinue
}

# ===========================================================================
# AIAgent — Register, Get, Remove
# ===========================================================================
Describe 'Register-AIAgent' {
    AfterEach {
        # Clean up any agents registered during tests
        @(Get-AIAgent) | ForEach-Object { Remove-AIAgent -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }
    }

    It 'registers a Claude agent and returns an AIAgent object' {
        $agent = Register-AIAgent -Name 'TestClaude' -Type Claude
        $agent                | Should -Not -BeNullOrEmpty
        $agent.Name           | Should -Be 'TestClaude'
        $agent.Type.ToString()| Should -Be 'Claude'
    }

    It 'registers a Gemini agent with default parameters' {
        $agent = Register-AIAgent -Name 'TestGemini' -Type Gemini `
            -DefaultParameters @{ model = 'gemini-pro' }
        $agent.DefaultParameters['model'] | Should -Be 'gemini-pro'
    }

    It 'registers a Custom agent with a specific executable path' {
        $agent = Register-AIAgent -Name 'MyBot' -Type Custom -ExecutablePath 'mybot.exe'
        $agent.ExecutablePath | Should -Be 'mybot.exe'
    }

    It 'throws when registering a duplicate agent without -Force' {
        Register-AIAgent -Name 'Dup' -Type Claude | Out-Null
        { Register-AIAgent -Name 'Dup' -Type Gemini } | Should -Throw
    }

    It 'overwrites a duplicate agent when -Force is used' {
        Register-AIAgent -Name 'Dup' -Type Claude -Force | Out-Null
        $agent = Register-AIAgent -Name 'Dup' -Type Gemini -Force
        $agent.Type.ToString() | Should -Be 'Gemini'
    }

    It 'sets IsAvailable to true when the executable is found' {
        # "pwsh" should be available in the current environment
        $agent = Register-AIAgent -Name 'PwshAgent' -Type Custom -ExecutablePath 'pwsh'
        $agent.IsAvailable | Should -Be $true
    }

    It 'sets IsAvailable to false when the executable is not found' {
        $agent = Register-AIAgent -Name 'NoExe' -Type Custom -ExecutablePath 'totally-does-not-exist-xyz'
        $agent.IsAvailable | Should -Be $false
    }
}

Describe 'Get-AIAgent' {
    BeforeAll {
        Register-AIAgent -Name 'AgentA' -Type Claude  | Out-Null
        Register-AIAgent -Name 'AgentB' -Type Gemini  | Out-Null
    }

    AfterAll {
        Remove-AIAgent -Name 'AgentA' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-AIAgent -Name 'AgentB' -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'returns a specific agent by name' {
        $a = Get-AIAgent -Name 'AgentA'
        $a.Name | Should -Be 'AgentA'
    }

    It 'returns all agents when no name is given' {
        $all = @(Get-AIAgent)
        $all.Count | Should -BeGreaterOrEqual 2
    }

    It 'throws when the agent name is not found' {
        { Get-AIAgent -Name 'NoSuchAgent' } | Should -Throw
    }
}

Describe 'Remove-AIAgent' {
    It 'removes a registered agent' {
        Register-AIAgent -Name 'ToRemove' -Type Claude | Out-Null
        Remove-AIAgent -Name 'ToRemove' -Confirm:$false
        { Get-AIAgent -Name 'ToRemove' } | Should -Throw
    }

    It 'throws when removing a non-existent agent' {
        { Remove-AIAgent -Name 'Ghost' -Confirm:$false } | Should -Throw
    }
}

# ===========================================================================
# Workflow — New, Add-Step, Get, Remove
# ===========================================================================
Describe 'New-Workflow' {
    AfterEach {
        @(Get-Workflow) | ForEach-Object { Remove-Workflow -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }
    }

    It 'creates a workflow and returns a Workflow object' {
        $wf = New-Workflow -Name 'WF1' -Description 'My workflow'
        $wf.Name        | Should -Be 'WF1'
        $wf.Description | Should -Be 'My workflow'
        $wf.Steps.Count | Should -Be 0
    }

    It 'stores workflow-level variables' {
        $wf = New-Workflow -Name 'WFVars' -Variables @{ Lang = 'Python' }
        $wf.Variables['Lang'] | Should -Be 'Python'
    }

    It 'throws when a duplicate name is used without -Force' {
        New-Workflow -Name 'WFDup' | Out-Null
        { New-Workflow -Name 'WFDup' } | Should -Throw
    }

    It 'overwrites an existing workflow when -Force is used' {
        New-Workflow -Name 'WFDup' -Description 'v1' | Out-Null
        $wf = New-Workflow -Name 'WFDup' -Description 'v2' -Force
        $wf.Description | Should -Be 'v2'
    }
}

Describe 'Add-WorkflowStep' {
    BeforeAll {
        Register-AIAgent -Name 'StepAgent' -Type Custom -ExecutablePath 'echo' | Out-Null
        $script:wf = New-Workflow -Name 'StepWF'
    }

    AfterAll {
        Remove-AIAgent   -Name 'StepAgent' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Workflow  -Name 'StepWF'   -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'adds a step to a workflow via the pipeline' {
        $step = $script:wf | Add-WorkflowStep -Name 'S1' -AgentName 'StepAgent' -PromptTemplate 'PT1'
        $step.Name        | Should -Be 'S1'
        $step.AgentName   | Should -Be 'StepAgent'
        $script:wf.Steps.Count | Should -BeGreaterOrEqual 1
    }

    It 'adds a step to a workflow by name' {
        $step = Add-WorkflowStep -WorkflowName 'StepWF' -Name 'S2' -AgentName 'StepAgent' -PromptTemplate 'PT2'
        $step.Name | Should -Be 'S2'
    }

    It 'sets MaxRetries and TimeoutSeconds correctly' {
        $step = $script:wf | Add-WorkflowStep -Name 'S3' -AgentName 'StepAgent' -PromptTemplate 'PT3' `
            -MaxRetries 3 -TimeoutSeconds 60
        $step.MaxRetries     | Should -Be 3
        $step.TimeoutSeconds | Should -Be 60
    }

    It 'marks a step as Parallel' {
        $step = $script:wf | Add-WorkflowStep -Name 'S4' -AgentName 'StepAgent' -PromptTemplate 'PT4' -Parallel
        $step.ExecutionMode.ToString() | Should -Be 'Parallel'
    }

    It 'throws when adding a duplicate step name' {
        { $script:wf | Add-WorkflowStep -Name 'S1' -AgentName 'StepAgent' -PromptTemplate 'dup' } | Should -Throw
    }

    It 'throws when the workflow name is not found' {
        { Add-WorkflowStep -WorkflowName 'NoWF' -Name 'X' -AgentName 'StepAgent' -PromptTemplate 'X' } | Should -Throw
    }
}

Describe 'Get-Workflow / Remove-Workflow' {
    BeforeAll {
        New-Workflow -Name 'GetWF1' | Out-Null
        New-Workflow -Name 'GetWF2' | Out-Null
    }

    AfterAll {
        Remove-Workflow -Name 'GetWF1' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Workflow -Name 'GetWF2' -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'retrieves a workflow by name' {
        $wf = Get-Workflow -Name 'GetWF1'
        $wf.Name | Should -Be 'GetWF1'
    }

    It 'retrieves all workflows' {
        $all = @(Get-Workflow)
        $all.Count | Should -BeGreaterOrEqual 2
    }

    It 'throws on unknown workflow name' {
        { Get-Workflow -Name 'NoWorkflow' } | Should -Throw
    }

    It 'removes a workflow' {
        New-Workflow -Name 'WFToRemove' | Out-Null
        Remove-Workflow -Name 'WFToRemove' -Confirm:$false
        { Get-Workflow -Name 'WFToRemove' } | Should -Throw
    }
}

# ===========================================================================
# Resolve-PromptTemplate (private — accessed via module scope)
# ===========================================================================
Describe 'Resolve-PromptTemplate' {
    It 'substitutes {Token} with context values' {
        $result = & (Get-Module OrchestrateQ) {
            Resolve-PromptTemplate -Template 'Hello {Name}!' -Context @{ Name = 'World' }
        }
        $result | Should -Be 'Hello World!'
    }

    It 'substitutes multiple tokens' {
        $result = & (Get-Module OrchestrateQ) {
            Resolve-PromptTemplate -Template '{A} {B} {C}' -Context @{ A = '1'; B = '2'; C = '3' }
        }
        $result | Should -Be '1 2 3'
    }

    It 'leaves unmatched tokens unchanged' {
        $result = & (Get-Module OrchestrateQ) {
            Resolve-PromptTemplate -Template 'Keep {Unknown}' -Context @{ Other = 'x' }
        }
        $result | Should -Be 'Keep {Unknown}'
    }

    It 'substitutes {Env.HOME} with the HOME environment variable' {
        $homeDir = [System.Environment]::GetEnvironmentVariable('HOME')
        if (-not $homeDir) { Set-ItResult -Skipped -Because 'HOME environment variable not set'; return }
        $result = & (Get-Module OrchestrateQ) {
            Resolve-PromptTemplate -Template 'Home={Env.HOME}' -Context @{}
        }
        $result | Should -Be "Home=$homeDir"
    }
}

# ===========================================================================
# Invoke-Workflow — sequential execution
# ===========================================================================
Describe 'Invoke-Workflow (sequential, mocked agent)' {
    BeforeAll {
        # Register a mock agent that echoes its prompt using the native 'echo' command
        Register-AIAgent -Name 'MockEcho' -Type Custom -ExecutablePath 'echo' | Out-Null
    }

    AfterAll {
        Remove-AIAgent -Name 'MockEcho' -Confirm:$false -ErrorAction SilentlyContinue
        @(Get-Workflow) | ForEach-Object { Remove-Workflow -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }
    }

    It 'executes a single-step workflow and returns output' {
        $wf = New-Workflow -Name 'SingleStep'
        $wf | Add-WorkflowStep -Name 'S1' -AgentName 'MockEcho' -PromptTemplate 'Echo: {Input}' | Out-Null

        $result = Invoke-Workflow -Name 'SingleStep' -Input 'test-data' -PassThru
        $result.Success             | Should -Be $true
        $result.StepResults.Count   | Should -Be 1
        $result.StepResults[0].Output | Should -Match 'test-data'
    }

    It 'passes PreviousOutput to subsequent steps' {
        $wf = New-Workflow -Name 'TwoStep'
        $wf | Add-WorkflowStep -Name 'S1' -AgentName 'MockEcho' -PromptTemplate '{Input}' | Out-Null
        $wf | Add-WorkflowStep -Name 'S2' -AgentName 'MockEcho' -PromptTemplate 'Prev={PreviousOutput}' | Out-Null

        $result = Invoke-Workflow -Name 'TwoStep' -Input 'mydata' -PassThru
        $result.StepResults[1].Output | Should -Match 'mydata'
    }

    It 'passes named-step output as {StepName.Output}' {
        $wf = New-Workflow -Name 'NamedRef'
        $wf | Add-WorkflowStep -Name 'First' -AgentName 'MockEcho' -PromptTemplate 'FirstResult' | Out-Null
        $wf | Add-WorkflowStep -Name 'Second' -AgentName 'MockEcho' -PromptTemplate 'Ref={First.Output}' | Out-Null

        $result = Invoke-Workflow -Name 'NamedRef' -Input '' -PassThru
        $result.StepResults[1].Output | Should -Match 'FirstResult'
    }

    It 'substitutes workflow-level variables in templates' {
        $wf = New-Workflow -Name 'VarWF' -Variables @{ Lang = 'Python' }
        $wf | Add-WorkflowStep -Name 'S1' -AgentName 'MockEcho' -PromptTemplate 'Lang={Lang}' | Out-Null

        $result = Invoke-Workflow -Name 'VarWF' -Input '' -PassThru
        $result.StepResults[0].Output | Should -Match 'Python'
    }

    It 'allows call-time variable overrides' {
        $wf = New-Workflow -Name 'OverrideVarWF' -Variables @{ Lang = 'Python' }
        $wf | Add-WorkflowStep -Name 'S1' -AgentName 'MockEcho' -PromptTemplate 'Lang={Lang}' | Out-Null

        $result = Invoke-Workflow -Name 'OverrideVarWF' -Input '' -Variables @{ Lang = 'Go' } -PassThru
        $result.StepResults[0].Output | Should -Match 'Go'
    }

    It 'returns a failure result when the agent is not registered' {
        $wf = New-Workflow -Name 'BadAgent'
        $wf | Add-WorkflowStep -Name 'S1' -AgentName 'NonExistentAgent' -PromptTemplate 'test' | Out-Null

        $result = Invoke-Workflow -Name 'BadAgent' -Input '' -PassThru
        $result.Success           | Should -Be $false
        $result.StepResults.Count | Should -Be 1
        $result.Errors.Count      | Should -BeGreaterOrEqual 1
    }

    It 'halts execution on step failure' {
        $wf = New-Workflow -Name 'HaltOnFail'
        $wf | Add-WorkflowStep -Name 'Fail' -AgentName 'NonExistentAgent' -PromptTemplate 'fail' | Out-Null
        $wf | Add-WorkflowStep -Name 'Never' -AgentName 'MockEcho'        -PromptTemplate 'should not run' | Out-Null

        $result = Invoke-Workflow -Name 'HaltOnFail' -Input '' -PassThru
        $result.Success           | Should -Be $false
        $result.StepResults.Count | Should -Be 1   # only the failed step
    }

    It 'returns just the output string when -PassThru is not specified' {
        $wf = New-Workflow -Name 'NoPassThru'
        $wf | Add-WorkflowStep -Name 'S1' -AgentName 'MockEcho' -PromptTemplate 'result-text' | Out-Null

        $output = Invoke-Workflow -Name 'NoPassThru' -Input ''
        $output | Should -BeOfType [string]
        $output | Should -Match 'result-text'
    }
}

# ===========================================================================
# Export-Workflow / Import-Workflow round-trip
# ===========================================================================
Describe 'Export-Workflow / Import-Workflow' {
    BeforeAll {
        Register-AIAgent -Name 'ExportAgent' -Type Custom -ExecutablePath 'echo' | Out-Null
        $wf = New-Workflow -Name 'ExportWF' -Description 'For export' -Variables @{ V = '42' }
        $wf | Add-WorkflowStep -Name 'E1' -AgentName 'ExportAgent' -PromptTemplate '{Input}' | Out-Null
        $wf | Add-WorkflowStep -Name 'E2' -AgentName 'ExportAgent' -PromptTemplate '{E1.Output}' `
            -DependsOn 'E1' -MaxRetries 2 -TimeoutSeconds 30 -Parallel | Out-Null
    }

    AfterAll {
        Remove-AIAgent  -Name 'ExportAgent' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Workflow -Name 'ExportWF'    -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item '/tmp/test-export.workflow.json' -ErrorAction SilentlyContinue
    }

    It 'exports a workflow to JSON without error' {
        { Export-Workflow -Name 'ExportWF' -Path '/tmp/test-export.workflow.json' -Force } | Should -Not -Throw
        '/tmp/test-export.workflow.json' | Should -Exist
    }

    It 'imports a workflow with correct properties' {
        Export-Workflow -Name 'ExportWF' -Path '/tmp/test-export.workflow.json' -Force

        Remove-Workflow -Name 'ExportWF' -Confirm:$false
        $imported = Import-Workflow -Path '/tmp/test-export.workflow.json'

        $imported.Name                       | Should -Be 'ExportWF'
        $imported.Description                | Should -Be 'For export'
        $imported.Variables['V']             | Should -Be '42'
        $imported.Steps.Count                | Should -Be 2
        $imported.Steps[1].DependsOn         | Should -Contain 'E1'
        $imported.Steps[1].MaxRetries        | Should -Be 2
        $imported.Steps[1].TimeoutSeconds    | Should -Be 30
        $imported.Steps[1].ExecutionMode.ToString() | Should -Be 'Parallel'
    }

    It 'throws when importing a non-existent file' {
        { Import-Workflow -Path '/tmp/does-not-exist.json' } | Should -Throw
    }
}

# ===========================================================================
# Invoke-AIAgent (direct)
# ===========================================================================
Describe 'Invoke-AIAgent' {
    BeforeAll {
        Register-AIAgent -Name 'DirectEcho' -Type Custom -ExecutablePath 'echo' | Out-Null
    }

    AfterAll {
        Remove-AIAgent -Name 'DirectEcho' -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'calls a registered agent and returns a string' {
        $response = Invoke-AIAgent -Name 'DirectEcho' -Prompt 'hello'
        $response | Should -BeOfType [string]
        $response | Should -Match 'hello'
    }

    It 'throws when calling an unregistered agent' {
        { Invoke-AIAgent -Name 'NotRegistered' -Prompt 'test' } | Should -Throw
    }
}
