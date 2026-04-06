# OrchestrateQ User Guide

## Overview

OrchestrateQ is a PowerShell module for working with CLI-based AI agents and composing them into reusable workflows. It is designed around two core ideas:

- **Agents** are named wrappers around AI CLIs such as Claude, Gemini, GitHub Copilot, OpenAI Codex, or any custom executable.
- **Workflows** are ordered sets of steps that invoke those agents with prompt templates and runtime context.

The module runs entirely in the current PowerShell session. Registered agents and workflows are kept in module-scoped memory unless you export workflows to disk.

## Requirements

- PowerShell 5.1 or later
- One or more supported AI CLIs installed and available on `PATH`, or a custom executable path
- Pester 5.x only if you plan to run the test suite

Supported built-in agent types and their default executable names:

| Agent type | Default executable |
| --- | --- |
| `Claude` | `claude` |
| `Gemini` | `gemini` |
| `Copilot` | `gh` |
| `Codex` | `codex` |
| `Custom` | No default, you should provide `-ExecutablePath` |

## Importing the Module

From the repository root:

```powershell
Import-Module .\src\OrchestrateQ\OrchestrateQ.psd1 -Force
```

To see the exported commands:

```powershell
Get-Command -Module OrchestrateQ
```

## Core Concepts

### Agent registry

`Register-AIAgent` stores agent definitions in a module-level registry keyed by name. That registry is case-insensitive and exists only for the current session.

Each agent stores:

- `Name`
- `Type`
- `ExecutablePath`
- `DefaultParameters`
- `IsAvailable`

`IsAvailable` only tells you whether PowerShell could resolve the executable when the agent was registered. It is not a health check and it is not refreshed automatically.

### Workflow registry

`New-Workflow` stores workflows in a second module-level registry. A workflow contains:

- `Name`
- `Description`
- `Steps`
- `Variables`
- `LogPath`
- `CreatedAt`
- `UpdatedAt`

Workflows are also session-scoped unless exported.

### Workflow steps

Each step identifies:

- The step `Name`
- The agent to call via `AgentName`
- A `PromptTemplate`
- Optional `Parameters`
- Execution mode: sequential or parallel
- Retry count
- Timeout
- Optional `OnSuccess` and `OnFailure` scriptblocks

## Registering Agents

### Basic registration

```powershell
Register-AIAgent -Name "Claude" -Type Claude
Register-AIAgent -Name "Gemini" -Type Gemini
Register-AIAgent -Name "Copilot" -Type Copilot
Register-AIAgent -Name "Codex" -Type Codex
```

### Custom executable

```powershell
Register-AIAgent -Name "MyBot" -Type Custom -ExecutablePath "C:\Tools\mybot.exe"
```

For `Custom` agents, `-ExecutablePath` is effectively required. Registration does not enforce it, but invocation will fail without it.

### Default parameters

Default parameters are merged into every invocation for that agent:

```powershell
Register-AIAgent -Name "GeminiPro" -Type Gemini `
    -DefaultParameters @{ model = "gemini-pro" }
```

At invocation time, per-call parameters override default values with the same key.

### Listing and removing agents

```powershell
Get-AIAgent
Get-AIAgent -Name "GeminiPro"
Remove-AIAgent -Name "GeminiPro" -Confirm:$false
```

## Invoking an Agent Directly

### Using a registered agent

```powershell
$response = Invoke-AIAgent -Name "Claude" -Prompt "Write a hello world script in Python"
$response
```

### Using a temporary agent by type

```powershell
$response = Invoke-AIAgent -Type Gemini -Prompt "Explain quantum computing in one sentence"
$response
```

For `-Type Custom`, provide `-ExecutablePath` unless the executable can be inferred some other way:

```powershell
$response = Invoke-AIAgent -Type Custom -ExecutablePath "echo" -Prompt "hello"
```

### Per-call parameters

```powershell
$response = Invoke-AIAgent -Name "GeminiPro" `
    -Prompt "Summarize the following text" `
    -Parameters @{ temperature = 0.2 }
```

### Retries

`Invoke-AIAgent` can retry direct calls:

```powershell
$response = Invoke-AIAgent -Name "Claude" `
    -Prompt "Generate three test cases" `
    -MaxRetries 2 `
    -RetryDelaySeconds 10
```

## Creating a Workflow

Create a workflow with a name, optional description, optional variables, and optional log path:

```powershell
$wf = New-Workflow -Name "CodeReview" `
    -Description "Analyze code, suggest improvements, and summarize findings" `
    -Variables @{ Language = "PowerShell" } `
    -LogPath ".\logs\CodeReview.log"
```

You can retrieve it later by name:

```powershell
Get-Workflow -Name "CodeReview"
```

## Adding Workflow Steps

You can add steps by piping a workflow object or by naming the workflow explicitly.

### Pipeline style

```powershell
$wf | Add-WorkflowStep -Name "Analyze" `
    -AgentName "Claude" `
    -PromptTemplate "Analyze this {Language} code:`n{Input}"
```

### By workflow name

```powershell
Add-WorkflowStep -WorkflowName "CodeReview" `
    -Name "Suggest" `
    -AgentName "Gemini" `
    -PromptTemplate "Based on this analysis:`n{Analyze.Output}`n`nSuggest improvements."
```

### Step parameters

Use `-Parameters` for per-step CLI flags:

```powershell
$wf | Add-WorkflowStep -Name "Draft" `
    -AgentName "Claude" `
    -PromptTemplate "Draft release notes for:`n{Input}" `
    -Parameters @{ model = "sonnet"; temperature = 0.3 }
```

### Parallel steps

Mark consecutive steps with `-Parallel` to execute them concurrently:

```powershell
$wf | Add-WorkflowStep -Name "Security" `
    -AgentName "Claude" `
    -PromptTemplate "Review this for security issues:`n{Input}" `
    -Parallel

$wf | Add-WorkflowStep -Name "Performance" `
    -AgentName "Gemini" `
    -PromptTemplate "Review this for performance issues:`n{Input}" `
    -Parallel

$wf | Add-WorkflowStep -Name "Merge" `
    -AgentName "Claude" `
    -PromptTemplate "Merge these findings:`nSecurity: {Security.Output}`nPerformance: {Performance.Output}"
```

### Retry and timeout settings

```powershell
$wf | Add-WorkflowStep -Name "FetchData" `
    -AgentName "Codex" `
    -PromptTemplate "Fetch and summarize:`n{Input}" `
    -MaxRetries 3 `
    -TimeoutSeconds 60
```

### Lifecycle hooks

```powershell
$wf | Add-WorkflowStep -Name "Generate" `
    -AgentName "Claude" `
    -PromptTemplate "Generate a script for:`n{Input}" `
    -OnSuccess { param($r) Write-Host "Completed in $($r.Duration.TotalSeconds)s seconds" } `
    -OnFailure { param($r) Write-Warning "Generation failed: $($r.Error)" }
```

## Prompt Templates and Runtime Tokens

Prompt templates are resolved immediately before a step runs.

Supported tokens:

| Token | Meaning |
| --- | --- |
| `{Input}` | The string passed to `Invoke-Workflow -Input` |
| `{PreviousOutput}` | The output from the most recently successful step |
| `{StepName.Output}` | The output from a named step |
| `{VariableName}` | A workflow variable or call-time override |
| `{Env.VAR_NAME}` | An environment variable |

Example:

```powershell
$wf | Add-WorkflowStep -Name "Summarize" `
    -AgentName "Claude" `
    -PromptTemplate @"
Repository: {RepoName}
Branch: {Env.BRANCH_NAME}
Prior output: {Analyze.Output}
New input:
{Input}
"@
```

Implementation note: the runtime context also includes a shorthand key for each step name, so `{Analyze}` currently resolves to the same value as `{Analyze.Output}`. Prefer the explicit `.Output` form for readability.

## Variables

### Workflow-level variables

Define defaults when creating the workflow:

```powershell
$wf = New-Workflow -Name "Docs" -Variables @{ Product = "OrchestrateQ"; Audience = "Users" }
```

### Call-time overrides

Provide overrides when executing:

```powershell
Invoke-Workflow -Name "Docs" `
    -Input "Create onboarding copy" `
    -Variables @{ Audience = "Administrators" }
```

Call-time values override workflow defaults with the same key.

## Running a Workflow

### Return only the final output

```powershell
$output = Invoke-Workflow -Name "CodeReview" -Input (Get-Content .\script.ps1 -Raw)
$output
```

### Return the full result object

```powershell
$result = Invoke-Workflow -Name "CodeReview" `
    -Input (Get-Content .\script.ps1 -Raw) `
    -PassThru

$result.Success
$result.Output
$result.Errors
$result.StepResults | Format-Table StepName, Success, RetryCount, Duration
```

### Running by object

```powershell
$wf | Invoke-Workflow -Input "Generate release notes" -PassThru
```

## Understanding Execution Behavior

### Sequential execution

Sequential steps run one at a time in the order they were added.

If a sequential step fails:

- Its `OnFailure` handler runs if one was provided.
- The workflow stops immediately.
- Later steps are not executed.

### Parallel execution

Consecutive steps marked with `-Parallel` are grouped and launched as PowerShell background jobs. The next sequential step runs only after the full parallel group completes.

If any parallel step fails:

- The workflow records the failure.
- The workflow stops after the parallel group completes.
- Later steps are not executed.

### Retry behavior

- Sequential workflow steps retry up to `MaxRetries` times with a fixed 3-second delay.
- Direct `Invoke-AIAgent` retries use `RetryDelaySeconds`.

### Timeout behavior

`TimeoutSeconds` is enforced only for parallel workflow steps, because those steps run through background jobs and are waited on with a timeout. Sequential steps do not currently have an execution timeout.

## Result Objects

### `WorkflowResult`

When you use `-PassThru`, OrchestrateQ returns a `WorkflowResult` with:

- `WorkflowName`
- `Success`
- `Output`
- `Errors`
- `StepResults`
- `StartTime`
- `EndTime`
- `Duration`

### `StepResult`

Each item in `StepResults` contains:

- `StepName`
- `Success`
- `Output`
- `Error`
- `RetryCount`
- `StartTime`
- `EndTime`
- `Duration`

## Exporting and Importing Workflows

### Export

```powershell
Export-Workflow -Name "CodeReview" -Path ".\workflows\CodeReview.workflow.json"
```

You can also export from the pipeline:

```powershell
Get-Workflow -Name "CodeReview" | Export-Workflow -Path ".\workflows\CodeReview.workflow.json"
```

### Import

```powershell
Import-Workflow -Path ".\workflows\CodeReview.workflow.json"
```

### What gets serialized

Workflow export includes:

- Workflow name and description
- Workflow variables
- Log path
- Step names
- Step agent names
- Prompt templates
- Step parameters
- `DependsOn`
- Execution mode
- Retry counts
- Timeout values

### What does not get serialized

Workflow export does not preserve:

- Registered agent definitions
- `OnSuccess` scriptblocks
- `OnFailure` scriptblocks
- The original workflow object timestamps exactly as created in memory

After importing a workflow, you still need to register any agents referenced by its steps before you can execute it successfully.

## Logging

If a workflow has `-LogPath` set, OrchestrateQ appends log entries to that file in UTF-8.

Each line uses this format:

```text
[yyyy-MM-dd HH:mm:ss.fff] [LEVEL] Message
```

Levels used internally:

- `INFO`
- `WARN`
- `ERROR`
- `DEBUG`

Important detail: informational messages are written with `Write-Verbose`, debug messages use `Write-Debug`, warnings use `Write-Warning`, and errors use `Write-Error`. If you want to see verbose or debug output in the console, enable the matching PowerShell preferences or use common parameters such as `-Verbose` and `-Debug` where available.

## CLI Argument Mapping

OrchestrateQ forwards parameters as CLI flags using a simple convention:

- Hashtable key `model` becomes `--model`
- Non-boolean values are emitted as `--key value`
- Boolean values are emitted as `--key`
- The prompt is appended according to each agent type

Built-in dispatch behavior:

- `Claude`: prompt is passed with `-p`
- `Gemini`: prompt is passed as the final positional argument
- `Copilot`: runs `gh copilot suggest -t <target>` and then appends the prompt
- `Codex`: prompt is passed as the final positional argument
- `Custom`: all parameters become `--key value` flags and the prompt is the final positional argument

For Copilot, `target` defaults to `shell` unless you override it in parameters.

## End-to-End Example

```powershell
Import-Module .\src\OrchestrateQ\OrchestrateQ.psd1 -Force

Register-AIAgent -Name "Reviewer" -Type Claude
Register-AIAgent -Name "Optimizer" -Type Gemini -DefaultParameters @{ model = "gemini-pro" }

$wf = New-Workflow -Name "CodeReview" `
    -Description "Review code and propose improvements" `
    -Variables @{ Language = "PowerShell" } `
    -LogPath ".\logs\CodeReview.log"

$wf | Add-WorkflowStep -Name "Analyze" `
    -AgentName "Reviewer" `
    -PromptTemplate "Analyze this {Language} code for correctness and maintainability:`n{Input}"

$wf | Add-WorkflowStep -Name "Suggest" `
    -AgentName "Optimizer" `
    -PromptTemplate "Based on this analysis:`n{Analyze.Output}`n`nSuggest concrete improvements."

$wf | Add-WorkflowStep -Name "Summarize" `
    -AgentName "Reviewer" `
    -PromptTemplate "Write a concise summary using:`nAnalysis: {Analyze.Output}`nSuggestions: {Suggest.Output}"

$code = Get-Content .\script.ps1 -Raw
$result = Invoke-Workflow -Name "CodeReview" -Input $code -PassThru

$result.StepResults | Format-Table StepName, Success, Duration
$result.Output
```

## Troubleshooting

### "No agent named 'X' is registered"

Register the agent first with `Register-AIAgent`, or call `Invoke-AIAgent` with `-Type` for a temporary one-off invocation.

### "Agent executable not found" behavior

Registration can succeed even when the executable is not installed. Check:

- `Get-AIAgent -Name "<name>" | Select-Object Name, Type, ExecutablePath, IsAvailable`
- Your `PATH`
- Any explicit `-ExecutablePath` you provided

### Workflow import succeeds but execution fails

Imported workflows do not recreate agent registrations. Re-register the referenced agents in the current session before calling `Invoke-Workflow`.

### A timeout did not stop a sequential step

That is current behavior. `TimeoutSeconds` is only enforced for steps inside a parallel group.

### A dependency did not delay a step

That is also current behavior. `DependsOn` is stored on workflow steps and is exported/imported, but execution is still driven by step order and parallel grouping rather than dependency resolution.

### Unexpected `{PreviousOutput}` after parallel work

Avoid using `{PreviousOutput}` after a parallel group. Use explicit references such as `{Security.Output}` and `{Performance.Output}` instead. The workflow engine updates `PreviousOutput` from the parallel results after the group finishes, which is not a strong coordination mechanism.

## Current Limitations and Cautions

- Agent and workflow registries are in-memory only for the current PowerShell session.
- Workflow execution does not currently enforce `DependsOn`.
- Sequential step timeouts are not implemented.
- Exported workflows do not preserve lifecycle hooks.
- Exported workflows do not include agent registrations.
- The Codex dispatcher does not use an `api_key` parameter value directly; prefer authenticating the CLI through its normal environment-based setup.
- Passing secrets as CLI flags may expose them to process inspection or logs. Prefer the authentication mechanism expected by the underlying CLI.

## Command Summary

| Cmdlet | Purpose |
| --- | --- |
| `Register-AIAgent` | Register an AI CLI wrapper by name |
| `Get-AIAgent` | List registered agents or fetch one by name |
| `Remove-AIAgent` | Remove a registered agent |
| `Invoke-AIAgent` | Send a prompt directly to an agent |
| `New-Workflow` | Create a workflow |
| `Add-WorkflowStep` | Add a step to a workflow |
| `Get-Workflow` | List workflows or fetch one by name |
| `Remove-Workflow` | Remove a workflow |
| `Invoke-Workflow` | Execute a workflow |
| `Export-Workflow` | Serialize a workflow to JSON |
| `Import-Workflow` | Load a workflow from JSON |

For command-level help:

```powershell
Get-Help Register-AIAgent -Full
Get-Help Invoke-Workflow -Full
```
