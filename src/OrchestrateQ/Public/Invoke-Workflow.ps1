function Invoke-Workflow {
    <#
    .SYNOPSIS
        Executes a registered workflow, orchestrating each step's AI agent call.

    .DESCRIPTION
        Steps are executed in the order they were added, with dependency and
        parallelism rules applied.

        Template tokens available in PromptTemplate:
          {Input}            - the string passed via -Input
          {PreviousOutput}   - the last successfully completed step's output
          {StepName.Output}  - the output of a specific named step
          {Variable.Key}     - a key from the workflow's Variables hashtable

        Parallel steps (marked with -Parallel in Add-WorkflowStep) are run
        concurrently using PowerShell background jobs.

    .PARAMETER Name
        The name of the workflow to run.

    .PARAMETER Workflow
        The Workflow object to run directly.

    .PARAMETER WorkflowInput
        The input string available as {Input} in all prompt templates.
        Can also be specified as -Input (alias).

    .PARAMETER Variables
        Additional variables to merge with the workflow's own variables.
        These are available as {Key} in prompt templates.

    .PARAMETER PassThru
        Return the full WorkflowResult object instead of just the final output string.

    .EXAMPLE
        Invoke-Workflow -Name "CodeReview" -Input "function add(a,b){ return a+b }"

    .EXAMPLE
        $result = Invoke-Workflow -Name "Research" -Input "quantum computing" -PassThru
        $result.StepResults | Format-Table
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([string], ParameterSetName = 'ByName')]
    [OutputType([string], ParameterSetName = 'ByObject')]
    [OutputType('WorkflowResult', ParameterSetName = 'ByNamePassThru')]
    [OutputType('WorkflowResult', ParameterSetName = 'ByObjectPassThru')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [Parameter(Mandatory, ParameterSetName = 'ByNamePassThru', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, ParameterSetName = 'ByObject', ValueFromPipeline)]
        [Parameter(Mandatory, ParameterSetName = 'ByObjectPassThru', ValueFromPipeline)]
        [Workflow] $Workflow,

        [Parameter()]
        [Alias("Input")][string] $WorkflowInput = "",

        [Parameter()]
        [hashtable] $Variables = @{},

        [Parameter(Mandatory, ParameterSetName = 'ByNamePassThru')]
        [Parameter(Mandatory, ParameterSetName = 'ByObjectPassThru')]
        [switch] $PassThru
    )

    process {
        $wf = if ($PSCmdlet.ParameterSetName -in 'ByName', 'ByNamePassThru') {
            if (-not $script:WorkflowRegistry.ContainsKey($Name)) {
                throw "No workflow named '$Name' is registered."
            }
            $script:WorkflowRegistry[$Name]
        }
        else { $Workflow }

        $result              = [WorkflowResult]::new($wf.Name)
        $previousOutput      = ''
        $stepOutputs         = @{}

        # Merge variables: workflow-level, then call-time overrides
        $effectiveVariables = @{} + $wf.Variables
        foreach ($k in $Variables.Keys) { $effectiveVariables[$k] = $Variables[$k] }

        Write-OrchestrateQLog "Starting workflow '$($wf.Name)' with $($wf.Steps.Count) step(s)" -LogPath $wf.LogPath

        # ----------------------------------------------------------------
        # Separate sequential and parallel groups (preserve order)
        # Groups: a run of consecutive Parallel steps forms one group.
        # ----------------------------------------------------------------
        $executionGroups = @()
        $i = 0
        while ($i -lt $wf.Steps.Count) {
            $step = $wf.Steps[$i]
            if ($step.ExecutionMode -eq [StepExecutionMode]::Parallel) {
                # Collect consecutive parallel steps
                $group = @()
                while ($i -lt $wf.Steps.Count -and $wf.Steps[$i].ExecutionMode -eq [StepExecutionMode]::Parallel) {
                    $group += $wf.Steps[$i]
                    $i++
                }
                $executionGroups += [pscustomobject]@{ Mode = 'Parallel';   Steps = $group }
            }
            else {
                $executionGroups += [pscustomobject]@{ Mode = 'Sequential'; Steps = @($step) }
                $i++
            }
        }

        # ----------------------------------------------------------------
        # Execute each group
        # ----------------------------------------------------------------
        $overallSuccess = $true

        foreach ($group in $executionGroups) {
            if ($group.Mode -eq 'Sequential') {
                $step       = $group.Steps[0]
                $stepResult = Invoke-WorkflowStepInternal `
                    -Step              $step `
                    -InputData         $WorkflowInput `
                    -PreviousOutput    $previousOutput `
                    -StepOutputs       $stepOutputs `
                    -WorkflowVariables $effectiveVariables `
                    -LogPath           $wf.LogPath

                $result.StepResults += $stepResult

                if ($stepResult.Success) {
                    $previousOutput             = $stepResult.Output
                    $stepOutputs[$step.Name]    = $stepResult.Output

                    if ($step.OnSuccess) {
                        try { & $step.OnSuccess $stepResult } catch { Write-OrchestrateQLog "OnSuccess handler error: $_" -Level WARN }
                    }
                }
                else {
                    $result.Errors += "Step '$($step.Name)' failed: $($stepResult.Error)"
                    $overallSuccess  = $false

                    if ($step.OnFailure) {
                        try { & $step.OnFailure $stepResult } catch { Write-OrchestrateQLog "OnFailure handler error: $_" -Level WARN }
                    }

                    Write-OrchestrateQLog "Step '$($step.Name)' failed — halting workflow." -Level ERROR -LogPath $wf.LogPath
                    break
                }
            }
            else {
                # Parallel group: launch all steps as background jobs
                $parallelResults = Invoke-ParallelStepGroup `
                    -Steps             $group.Steps `
                    -InputData         $WorkflowInput `
                    -PreviousOutput    $previousOutput `
                    -StepOutputs       $stepOutputs `
                    -WorkflowVariables $effectiveVariables `
                    -LogPath           $wf.LogPath

                foreach ($sr in $parallelResults) {
                    $result.StepResults += $sr

                    if ($sr.Success) {
                        $stepOutputs[$sr.StepName] = $sr.Output
                        $previousOutput            = $sr.Output   # last parallel output wins
                    }
                    else {
                        $result.Errors += "Step '$($sr.StepName)' failed: $($sr.Error)"
                        $overallSuccess  = $false
                    }
                }

                if (-not $overallSuccess) {
                    Write-OrchestrateQLog "One or more parallel steps failed — halting workflow." -Level ERROR -LogPath $wf.LogPath
                    break
                }
            }
        }

        $result.Complete($overallSuccess)
        Write-OrchestrateQLog "Workflow '$($wf.Name)' completed. Success=$overallSuccess, Duration=$($result.Duration)" -LogPath $wf.LogPath

        if ($PassThru) {
            return $result
        }

        return $result.Output
    }
}

# -----------------------------------------------------------------------
# Internal helpers (not exported)
# -----------------------------------------------------------------------

function Invoke-WorkflowStepInternal {
    [OutputType('StepResult')]
    param(
        [WorkflowStep] $Step,
        [string]       $InputData,
        [string]       $PreviousOutput,
        [hashtable]    $StepOutputs,
        [hashtable]    $WorkflowVariables,
        [string]       $LogPath
    )

    $stepResult = [StepResult]::new($Step.Name)

    Write-OrchestrateQLog "Executing step '$($Step.Name)' with agent '$($Step.AgentName)'" -LogPath $LogPath

    # Build template context
    $context = @{ Input = $InputData; PreviousOutput = $PreviousOutput }
    foreach ($k in $WorkflowVariables.Keys) { $context[$k] = $WorkflowVariables[$k] }
    foreach ($k in $StepOutputs.Keys) {
        $context["$k.Output"] = $StepOutputs[$k]
        $context[$k]          = $StepOutputs[$k]   # shorthand alias
    }

    $resolvedPrompt = Resolve-PromptTemplate -Template $Step.PromptTemplate -Context $context

    if (-not $script:AgentRegistry.ContainsKey($Step.AgentName)) {
        $stepResult.Complete($false, $null, "Agent '$($Step.AgentName)' is not registered.")
        return $stepResult
    }

    $agent   = $script:AgentRegistry[$Step.AgentName]
    $attempt = 0

    do {
        try {
            $output = Invoke-AgentDispatch -Agent $agent -Prompt $resolvedPrompt -Parameters $Step.Parameters
            $stepResult.Complete($true, ($output | Out-String).Trim(), $null)
            Write-OrchestrateQLog "Step '$($Step.Name)' succeeded." -LogPath $LogPath
            break
        }
        catch {
            $attempt++
            if ($attempt -le $Step.MaxRetries) {
                Write-OrchestrateQLog "Step '$($Step.Name)' failed (attempt $attempt): $_. Retrying..." -Level WARN -LogPath $LogPath
                Start-Sleep -Seconds 3
            }
            else {
                $stepResult.RetryCount = $attempt - 1
                $stepResult.Complete($false, $null, $_.ToString())
                Write-OrchestrateQLog "Step '$($Step.Name)' failed after $attempt attempt(s): $_" -Level ERROR -LogPath $LogPath
                break
            }
        }
    } while ($attempt -le $Step.MaxRetries)

    return $stepResult
}

function Invoke-ParallelStepGroup {
    [OutputType('StepResult[]')]
    param(
        [WorkflowStep[]] $Steps,
        [string]         $InputData,
        [string]         $PreviousOutput,
        [hashtable]      $StepOutputs,
        [hashtable]      $WorkflowVariables,
        [string]         $LogPath
    )

    $results = @()
    $jobs    = @{}

    foreach ($step in $Steps) {
        $context = @{ Input = $InputData; PreviousOutput = $PreviousOutput }
        foreach ($k in $WorkflowVariables.Keys) { $context[$k] = $WorkflowVariables[$k] }
        foreach ($k in $StepOutputs.Keys) {
            $context["$k.Output"] = $StepOutputs[$k]
            $context[$k]          = $StepOutputs[$k]
        }

        $resolvedPrompt = Resolve-PromptTemplate -Template $step.PromptTemplate -Context $context

        if (-not $script:AgentRegistry.ContainsKey($step.AgentName)) {
            $sr = [StepResult]::new($step.Name)
            $sr.Complete($false, $null, "Agent '$($step.AgentName)' is not registered.")
            $results += $sr
            continue
        }

        $agent = $script:AgentRegistry[$step.AgentName]

        Write-OrchestrateQLog "Launching parallel step '$($step.Name)'" -LogPath $LogPath

        # Pass only primitives to the job so no class type resolution is needed
        $agentData = @{
            Type              = $agent.Type.ToString()
            ExecutablePath    = $agent.ExecutablePath
            DefaultParameters = $agent.DefaultParameters
        }

        $job = Start-Job -ScriptBlock {
            param($agentData, $prompt, $stepParams)

            $exe    = $agentData.ExecutablePath
            $type   = $agentData.Type
            $merged = @{} + $agentData.DefaultParameters
            foreach ($k in $stepParams.Keys) { $merged[$k] = $stepParams[$k] }

            $argList = @()

            switch ($type) {
                'Claude' {
                    foreach ($k in $merged.Keys) {
                        $argList += "--$k"
                        if ($merged[$k] -isnot [bool]) { $argList += $merged[$k] }
                    }
                    $argList += '-p'
                    $argList += $prompt
                    if (-not $exe) { $exe = 'claude' }
                }
                'Gemini' {
                    foreach ($k in $merged.Keys) {
                        $argList += "--$k"
                        if ($merged[$k] -isnot [bool]) { $argList += $merged[$k] }
                    }
                    $argList += $prompt
                    if (-not $exe) { $exe = 'gemini' }
                }
                'Copilot' {
                    $target = if ($merged.ContainsKey('target')) { $merged['target'] } else { 'shell' }
                    $argList = @('copilot', 'suggest', '-t', $target)
                    foreach ($k in $merged.Keys) {
                        if ($k -notin @('target')) {
                            $argList += "--$k"
                            if ($merged[$k] -isnot [bool]) { $argList += $merged[$k] }
                        }
                    }
                    $argList += $prompt
                    if (-not $exe) { $exe = 'gh' }
                }
                'Codex' {
                    foreach ($k in $merged.Keys) {
                        if ($k -ne 'api_key') {
                            $argList += "--$k"
                            if ($merged[$k] -isnot [bool]) { $argList += $merged[$k] }
                        }
                    }
                    $argList += $prompt
                    if (-not $exe) { $exe = 'codex' }
                }
                default {
                    # Custom
                    foreach ($k in $merged.Keys) {
                        $argList += "--$k"
                        if ($merged[$k] -isnot [bool]) { $argList += $merged[$k] }
                    }
                    $argList += $prompt
                }
            }

            $output = & $exe @argList 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "$type agent exited with code ${LASTEXITCODE}: $output"
            }
            return ($output | Out-String).Trim()
        } -ArgumentList $agentData, $resolvedPrompt, $step.Parameters

        $jobs[$step.Name] = @{ Job = $job; Step = $step }
    }

    # Wait for all parallel jobs
    foreach ($key in $jobs.Keys) {
        $entry = $jobs[$key]
        $step  = $entry.Step
        $job   = $entry.Job
        $sr    = [StepResult]::new($step.Name)

        $completed = Wait-Job -Job $job -Timeout $step.TimeoutSeconds
        if (-not $completed) {
            Stop-Job   -Job $job
            Remove-Job -Job $job -Force
            $sr.Complete($false, $null, "Timed out after $($step.TimeoutSeconds)s.")
        }
        else {
            try {
                $output = Receive-Job -Job $job -ErrorAction Stop
                Remove-Job -Job $job -Force
                $sr.Complete($true, ($output | Out-String).Trim(), $null)
            }
            catch {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                $sr.Complete($false, $null, $_.ToString())
            }
        }

        if ($step.OnSuccess -and $sr.Success) {
            try { & $step.OnSuccess $sr } catch { Write-OrchestrateQLog "OnSuccess error: $_" -Level WARN }
        }
        if ($step.OnFailure -and -not $sr.Success) {
            try { & $step.OnFailure $sr } catch { Write-OrchestrateQLog "OnFailure error: $_" -Level WARN }
        }

        $results += $sr
    }

    return $results
}
