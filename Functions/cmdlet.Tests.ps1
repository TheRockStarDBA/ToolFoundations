Import-Module ToolFoundations -Force

Describe Get-BoundParams {
    BeforeEach {
        Remove-Module ToolFoundations -ea SilentlyContinue
        Import-Module ToolFoundations
    }
    BeforeEach {
        Function Test-GetBoundParams
        {
            [CmdletBinding()]
            param($p1,$p2,$test)
            process
            {
                switch ($test)
                {
                    1 { Get-BoundParams     }
                    2 { & (Get-BoundParams) }
                    3 { & (gbpm)            }
                    4 { & (gbpm -IncludeCommonParameters ) }
                }
            }
        }
    }

    AfterEach {
        Remove-Item function:Test-GetBoundParams -force
    }

    It "outputs [scriptblock]" {
        (Test-GetBoundParams -test 1) -is [scriptblock] |
            Should be $true
    }
    It "produces an object with the bound parameters as properties (test 2)." {
        $o = Test-GetBoundParams -test 2 -p1 'foo' -p2 123456

        $o.p1 | Should be 'foo'
        $o.p2 | Should be 123456
    }
    It "produces an object with the bound parameters as properties (test 3)." {
        $o = Test-GetBoundParams -test 3 -p1 'foo' -p2 123456

        $o.p1 | Should be 'foo'
        $o.p2 | Should be 123456
    }
    It "omits a common parameter. (test 3)" {
        $o = Test-GetBoundParams -test 3 -p1 'foo' -p2 123456 -Verbose

        $o.p1 | Should be 'foo'
        $o.p2 | Should be 123456
        $o -Contains 'Verbose' | Should be $false
    }
    It "includes a common parameter. (test 4)" {
        $o = Test-GetBoundParams -test 4 -p1 'foo' -p2 123456 -Verbose

        $o.p1 | Should be 'foo'
        $o.p2 | Should be 123456
        $o.Keys -Contains 'Verbose' | Should be $true
    }
}
InModuleScope ToolFoundations {
    Describe Get-CommonParams {
        BeforeAll {
            Function Test-CommonParams1
            {
                [CmdletBinding()]
                param($params=@{})
                process
                {
                    $oSplat = &(gcp @params)
                    Test-CommonParams2 @oSplat
                }
            }
            Function Test-CommonParams2
            {
                [CmdletBinding()]
                param()
                process{&(gbpm -IncludeCommonParameters )}
            }
        }
        AfterAll {
            Remove-Item function:Test-CommonParams1 -Force
            Remove-Item function:Test-CommonParams2 -Force
        }
        It 'outputs [scriptblock].' {
            $r = gcp

            $r -is [scriptblock] |
                Should be $true
        }
        It 'defaults to empty hashtable.' {
            $result = (&(gcp))

            $result -is [hashtable] |
                Should be $true
            $result.Keys |
                Should beNullOrEmpty
        }
        It 'cascades -Verbose. (True)' {
            $bp = Test-CommonParams1 -Verbose

            $bp.Keys -Contains 'Verbose' |
                Should be $true
            $bp.Verbose |
                Should be $true
            $bp.Keys.Count |
                Should be 1
        }
        It 'cascades -Verbose. (False)' {
            $bp = Test-CommonParams1 -Verbose:$false

            $bp.Keys -Contains 'Verbose' |
                Should be $true
            $bp.Verbose |
                Should be $false
            $bp.Keys.Count |
                Should be 1
        }
        Context 'bad ParamList item' {
            Mock Write-Error -Verifiable
            It 'returns hashtable with remaining items.' {
                $bp = Test-CommonParams1 -Verbose -params @{ParamList = 'Verbose','Invalid'}

                $bp.Keys -contains 'Verbose' |
                    Should be $true
                $bp.Keys.Count |
                    Should be 1
            }
            It 'reports correct error.' {
                Assert-MockCalled Write-Error -Exactly -Times 1
                Assert-MockCalled Write-Error -Exactly -Times 1 {
                    $Message -eq '"Invalid" is not a valid Common Parameter.'
                }
            }
        }
    }
}
Describe Publish-Failure {
    Context 'specified exception' {
        function Fail
        {
            &(Publish-Failure 'My Error Message','param1' -ExceptionType System.ArgumentException -FailAction Throw)
        }
        It 'throws correct exception.' {
            try
            {
                Fail
            }
            catch [System.ArgumentException]
            {
                $threw = $true

                $_.CategoryInfo.Reason | Should be 'ArgumentException'
                $_ | Should Match 'My Error Message'
                $_ | Should Match 'Parameter name: param1'

                if ($PSVersionTable.PSVersion.Major -ge 4)
                {
                    $_.ScriptStackTrace | Should Match 'at Fail, '
                    $_.ScriptStackTrace | Should not match 'cmdlet.ps1'
                }
            }
            $threw | Should be $true
        }
    }
    Context 'unspecified exception type' {
        function Fail
        {
            &(Publish-Failure 'My Error Message','param1' -FailAction Throw)
        }
        It 'throws a generic exception.' {
            try
            {
                Fail
            }
            catch
            {
                $threw = $true

                $_.CategoryInfo.Reason | Should be 'Exception'
                $_ | Should Match 'My Error Message'
            }
            $threw | Should be $true
        }
    }
    Context 'Verbose' {
        function Fail
        {
            &(Publish-Failure 'My Error Message','param1' -ExceptionType System.ArgumentException -FailAction Verbose)
        }
        Mock Write-Verbose -Verifiable
        It 'reports correct error message.' {
            Fail

            Assert-MockCalled Write-Verbose -Times 1 {
                $Message -eq 'My Error Message'
            }
        }
    }
    Context 'Error' {
        function Fail
        {
            &(Publish-Failure 'My Error Message','param1' -ExceptionType System.ArgumentException -FailAction Error)
        }
        Mock Write-Error -Verifiable
        It 'reports correct error message.' {
            Fail

            Assert-MockCalled Write-Error -Times 1 {
                $Message -eq 'My Error Message'
            }
        }
    }
}
Describe ConvertTo-ParamObject {
    It 'outputs a psobject with correct properties (1)' {
        $r = @{a=1} | ConvertTo-ParamObject
        $r -is [psobject] | Should be true

        $r |
            Get-Member |
            ? {
                $_.MemberType -like '*property*' -and
                $_.Name -eq 'a'
            } |
            Measure | % {$_.Count} |
            Should be 1
    }
    It 'outputs a psobject with correct properties (2)' {
        $h = @{
            string  = 'this is a string'
            integer = 12345678
            boolean = $true
            hashtable = @{a=1}
            array = 1,2,3
        }
        $r = $h | ConvertTo-ParamObject
        $r.string | Should be 'this is a string'
        $r.integer | Should be 12345678
        $r.boolean | Should be $true
        $r.hashtable.a | Should be 1
        $r.array[1] | Should be 2

        $r |
            Get-Member |
            ? {$_.MemberType -like '*property*'} |
            % {$_.Name} |
            ? {$h.keys -contains $_} |
            measure | % {$_.Count} |
            Should be 5
    }
    It 'accepts an object.' {
        $h = @{
            string  = 'this is a string'
            integer = 12345678
            boolean = $true
            hashtable = @{a=1}
            array = 1,2,3
        }
        $o = New-Object psobject -Property $h
        $r = $o | ConvertTo-ParamObject
        $r.string | Should be 'this is a string'
        $r.integer | Should be 12345678
        $r.boolean | Should be $true
        $r.hashtable.a | Should be 1
        $r.array[1] | Should be 2
    }
    It 'does not recurse.' {
        $h = @{
            h = @{
                a=1
            }
        }
        $r = $h | ConvertTo-ParamObject
        $r.h -is [hashtable] | Should be $true
    }
    It 'creates correct object from PSBoundParameters.'{
        $dict = New-Object 'System.Collections.Generic.Dictionary`2[System.String,System.Object]'
        ('string',    'this is a string' ),
        ('integer',   12345678 ),
        ('boolean',   $true ),
        ('hashtable', @{a=1} ),
        ('array',     @(1,2,3) ) |
            % {
                $dict.Add($_[0],$_[1])
            }
        $r = $dict | ConvertTo-ParamObject
        $r.string | Should be 'this is a string'
        $r.integer | Should be 12345678
        $r.boolean | Should be $true
        $r.hashtable.a | Should be 1
        $r.array[1] | Should be 2
    }
}
