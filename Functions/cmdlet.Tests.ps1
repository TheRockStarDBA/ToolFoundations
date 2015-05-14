Describe Get-BoundParams {
    BeforeEach {
        Remove-Module a9Foundations -ea SilentlyContinue
        Import-Module a9Foundations
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
                    4 { & (gbpm -in )       }
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
InModuleScope a9Foundations {
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
                process{&(gbpm -in)}
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
