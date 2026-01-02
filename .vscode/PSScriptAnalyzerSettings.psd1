@{
    Rules = @{
        PSUseCompatibleTypes = @{
            Enable = $false
        }
    }
    ExcludeRules = @(
        'PSAvoidUsingCmdletAliases'
    )
}
