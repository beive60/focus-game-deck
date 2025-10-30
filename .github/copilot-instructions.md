# GitHub Copilot Instructions

When generating code for this project, strictly follow the rules below.

## Essential Reference Documents

This project must follow the rules documented in the following files:

- `./docs/DOCUMENTATION-INDEX.md`
- `./docs/developer-guide/architecture.md`
- `./docs/developer-guide/build-system.md`
- `./docs/developer-guide/gui-design.md`
- `./docs/developer-guide/release-process.md`
- `./docs/project-info/philosophy.md`
- `./docs/project-info/roadmap.md`
- `./docs/project-info/version-management.md`

## Writing paths

- When writing file paths or directory paths, always use relative paths from the project root directory whenever possible.
- When writing file paths or directory paths, always use a forward slash (/) regardless of the operating system. Do not use a backslash (\\).
    - This rule is important for cross-platform compatibility and to avoid issues related to escape characters.

Good examples:

```powershell
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath ".."
$messagesPath = Join-Path -Path $projectRoot -ChildPath "gui/messages.json"
```

Bad examples:

```powershell
$messagesPath = "gui\messages.json"
```

## Attribute Wrapping in XAML

When writing XAML code, if an element has multiple attributes, each attribute should be placed on a new line and indented for better readability.

## Not use emoji

When generating documentation, terminal output, or any other content, do not use emojis. Keep all text plain and professional without any emoji characters or symbols.

## Not use "Column Alignment"

Do not use "Column Alignment" in any code, documentation, or comments. Avoid aligning code or text into columns for better readability and maintainability.

## PowerShell Cmdlet Verb Naming

When naming cmdlets, always use approved PowerShell verb names as defined by Microsoft. Below is a list of the approved verb names categorized by their intended use:

- Common Verbs (System.Management.Automation.VerbsCommon): defines general actions applicable to almost all cmdlets.
    - Add: Adds a resource to a container or attaches an item to another item.
    - Clear: Removes all resources from a container but does not delete the container.
    - Close: Changes the state of a resource so that it is inaccessible, unusable, or unavailable.
    - Copy: Copies a resource to another name or another container.
    - Enter: Specifies an action that allows a user to move into a resource.
    - Exit: Sets the current environment or context to the most recently used context.
    - Find: Searches for an object in an unknown, implicit, optional, or specified container.
    - Format: Arranges the object in the specified form or layout.
    - Get: Specifies an action to retrieve a resource.
    - Hide: Makes a resource undetectable.
    - Join: Combines resources into one resource.
    - Lock: Secures a resource.
    - Move: Moves a resource from one location to another.
    - New: Creates a resource.
    - Open: Changes the state of a resource so that it is accessible, available, or usable.
    - Optimize: Improves the effectiveness of a resource.
    - Pop: Removes an item from the top of the stack.
    - Push: Adds an item to the top of the stack.
    - Redo: Resets a resource to an undone state.
    - Remove: Deletes a resource from a container.
    - Rename: Changes the name of a resource.
    - Reset: Returns a resource to its original state.
    - Resize: Changes the size of a resource.
    - Search: Creates a reference to a resource in a container.
    - Select: Finds resources in a container.
    - Set: Replaces data in an existing resource or creates a resource that contains data (if it does not exist).
    - Show: Displays the resource to the user.
    - Skip: Bypasses one or more resources or points in a sequence.
    - Split: Separates a part of a resource.
    - Step: Moves to the next point or resource in a sequence.
    - Switch: Specifies an action that alternates between two resources.
    - Undo: Sets the resource to a previous state.
    - Unlock: Releases a locked resource.
    - Watch: Continuously examines or monitors changes to a resource.
- Communication Verbs (System.Management.Automation.VerbsCommunications): defines actions applicable to communication.
    - Connect: Creates a link between the source and the destination.
    - Disconnect: Breaks the link between the source and the destination.
    - Read: Retrieves information from a source.
    - Receive: Accepts information sent from a source.
    - Send: Delivers information to a destination.
    - Write: Adds information to a target.
- Data Verbs (System.Management.Automation.VerbsData): defines actions applicable to data processing.
    - Backup: Replicates and stores data.
    - Checkpoint: Creates a snapshot of the current state of data or its configuration.
    - Compare: Compares and evaluates the data of one resource against the data of another resource.
    - Compress: Compresses the data of a resource.
    - Convert: Changes data from one representation to another when the cmdlet supports bidirectional conversion or conversion between multiple data types.
    - ConvertFrom: Converts a primary type input to one or more supported output types.
    - ConvertTo: Converts from one or more types of input to a primary output type.
    - Dismount: Detaches a named entity from a location.
    - Edit: Modifies existing data by adding or deleting content.
    - Expand: Restores compressed resource data to its original state.
    - Export: Encapsulates the primary input into a persistent data store, such as a file, or an interchange format.
    - Group: Arranges or associates one or more resources.
    - Import: Creates a resource from data stored in a persistent data store (such as a file) or interchange format.
    - Initialize: Prepares the resource for use and sets it to the default state.
    - Limit: Applies constraints to a resource.
    - Merge: Creates one resource from multiple resources.
    - Mount: Attaches a named entity to a location.
    - Out: Sends data out of the environment.
    - Publish: Makes a resource available to other users.
    - Restore: Sets the resource to a predefined state, such as a state set by Checkpoint.
    - Save: Preserves data to avoid loss.
    - Sync: Ensures that two or more resources are in the same state.
    - Unpublish: Makes a resource unavailable to other users.
    - Update: Keeps the resource up-to-date to maintain state, accuracy, adherence, or compliance.
- Diagnostic Verbs (System.Management.Automation.VerbsDiagnostic): defines actions applicable to diagnostics.
    - Debug: Examines a resource to diagnose operational problems.
    - Measure: Identifies resources used by a specified operation or obtains statistical information about a resource.
    - Ping: Deprecated - Use the Test verb instead.
    - Repair: Restores a resource to usable conditions.
    - Resolve: Maps a shortened representation of a resource to a more complete representation.
    - Test: Verifies the operation or consistency of a resource.
    - Trace: Tracks the activity of a resource.
- Lifecycle Verbs (System.Management.Automation.VerbsLifecycle): defines actions applicable to the lifecycle of resources.
    - Approve: Confirms or agrees to the state of a resource or process.
    - Assert: Confirms the state of a resource.
    - Build: Creates artifacts (usually binaries or documents) from some input files (usually source code or declarative documents). This verb was added in PowerShell 6.
    - Complete: Ends an operation.
    - Confirm: Confirms, validates, or verifies the state of a resource or process.
    - Deny: Rejects, objects to, blocks, or opposes the state of a resource or process.
    - Deploy: Sends an application, website, or solution to a remote target so that consumers of that solution can access it after the deployment is complete. This verb was added in PowerShell 6.
    - Disable: Configures a resource to an unusable or inactive state.
    - Enable: Configures a resource to a usable or active state.
    - Install: Places a resource in a location and initializes it if necessary.
    - Invoke: Performs an action, such as executing a command or method.
    - Register: Creates an entry for a resource in a repository, such as a database.
    - Request: Requests a resource or permission.
    - Restart: Stops an operation and then starts it again.
    - Resume: Starts a suspended operation.
    - Start: Begins an operation.
    - Stop: Aborts an activity.
    - Submit: Presents a resource for approval.
    - Suspend: Temporarily stops an activity.
    - Uninstall: Removes a resource from the specified location.
    - Unregister: Removes the entry for a resource from the repository.
    - Wait: Pauses an operation until a specified event occurs.
- Security Verbs (System.Management.Automation.VerbsSecurity): defines actions applicable to security.
    - Block: Restricts access to a resource.
    - Grant: Allows access to a resource.
    - Protect: Protects a resource from attack or loss.
    - Revoke: Specifies an action that denies access to a resource.
    - Unblock: Removes restrictions on a resource.
    - Unprotect: Removes safeguards from a resource that were added to prevent attack or loss.
- Other Verbs (System.Management.Automation.VerbsOther): defines canonical verb names that do not fit into specific verb name categories.
    - Use: Uses or includes a resource and performs something.

## Conclusion

Do not suggest code that does not comply with the above rules.
