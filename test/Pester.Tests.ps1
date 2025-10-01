Describe 'Sample Pester Test' {
    It 'should return true for true' {
        $result = $true
        $result | Should -Be $true
    }
}