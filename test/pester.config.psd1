@{
    Run = @{
        Path = './test'
        Exit = $true
        PassThru = $true
    }

    Filter = @{
        Tag = @()           # Run tests with these tags (empty = all)
        ExcludeTag = @()    # Skip tests with these tags
    }

    Output = @{
        Verbosity = 'Detailed'  # None, Normal, Detailed, Diagnostic
    }

    CodeCoverage = @{
        Enabled = $false  # Set to $true when needed
        Path = @(
            './src/**/*.ps1',
            './gui/**/*.ps1'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = './test/coverage.xml'
    }

    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './test/test-results.xml'
    }
}
