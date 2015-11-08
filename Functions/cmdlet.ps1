Set-Alias gbpm Get-BoundParams
Set-Alias gcp Get-CommonParams

Function Get-BoundParams
{
<#
.SYNOPSIS
A terse way to get the cmdlet's bound parameters.

.DESCRIPTION
The alias gbpm for Get-BoundParams can be use to obtain the current cmdlet's bound parameters in a terse manner.  Get-BoundParams allows for this terse alternative to $PSCmdlet.MyInvocation.BoundParameters:

  &(gbpm)

A test for the existence of a parameter in an advanced function then becomes the following:

  if ( (&(gbpm)).Keys -contains 'SomeParameter' )


.OUTPUTS
A scriptblock that evaluates to the cmdlet's bound parameters.

.EXAMPLE
    function f1 {
        [CmdletBinding()]
        param($p1)
        process
        {
            if
            (
                (&(gbpm)).Keys -contains 'p1' -and  # tests existence of parameter
                -not $p1                      # tests value of parameter
            )
            {
                Write-Host 'p1 provided, but false'
            }
        }
    }

    f1 -p1 $false

This demonstrates the difference between testing the value and testing the existence of a parameter.  Get-BoundParams streamlines testing for existence of parameters.
#>
    [CmdletBinding()]
    param
    (
        # Get-BoundParams normally only provides user-defined parameters.  Set this switch to include common parameters.
        [switch]
        [Alias('cp')]
        $IncludeCommonParameters,

        # Get-BoundParams normally returns a scriptblock.  Set this switch to return the code string used to create the scriptblock, instead.
        [switch]
        $Code

    )
    process
    {
        if ( $IncludeCommonParameters )
        {
            $codeString = "iex '`$PSCmdlet.MyInvocation.BoundParameters'"
        }
        else
        {
            $codeString = @'
                $cp = [System.Management.Automation.PSCmdlet]::CommonParameters
                $bp = iex "`$PSCmdlet.MyInvocation.BoundParameters"
                $ncbp = @{}
                $bp.Keys |
                    ? { $cp -notContains $_ } |
                    % {
                        $ncbp[$_] = $bp[$_]
                    }
                $ncbp

'@
        }
        if ($Code) { return $codeString }
        [scriptblock]::Create($codeString)
    }
}
Function Get-CommonParams
{
<#
.SYNOPSIS
A terse way to get cascade common parameters from one cmdlet to another.

.DESCRIPTION
The alias gcp for Get-CommonParams can be use to cascade the parameters that control output streams from one cmdlet to another.  Get-CommonParams allows for this terse usage:

  $cp = &(gcp)
  Invoke-SomeOtherFunction @cp

.OUTPUTS
A scriptblock that evaluates to the hashtable that, when passed as splat parameters to another cmdlet, cascades the common parameters of the calling cmdlet to that cmdlet.

.EXAMPLE
    function f1 {
        [CmdletBinding()]
        param()
        process
        {
            $cp = &(gcp)
            f2 @cp
        }
    }
    function f2 {
        [CmdletBinding()]
        param()
        process
        {
            Write-Verbose 'This gets output to the Verbose stream.'
        }
    }

    f1 -Verbose

This demonstrates how to use Get-CommonParams to cascade the value and existence of the Verbose switch from cmdlet f1 to cmdlet f2.
#>
    [CmdletBinding()]
    param
    (
        # The list of output stream parameters to cascade
        [parameter(ValueFromPipeline               = $true,
                   Position                        = 1,
                   ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ParamList = ('Debug','ErrorAction','ErrorVariable','Verbose',
                      'WarningAction','WarningVariable','WhatIf','Confirm'),

        # Get-CommonParams normally returns a scriptblock.  Set this switch to return the code string used to create the scriptblock, instead.
        [switch]
        $Code
    )
    process
    {
        $commonParameters = Get-CommonParameterNames

        if ( (&(gbpm)).Keys -contains 'ParamList' )
        {
            $pl = $ParamList
        }
        else
        {
            $pl = Get-CommonParameterNames
        }

        # get the valid output stream names
        $vcp = $pl |
            % {
                if ( $commonParameters -Contains $_ ) { $_ }
                else
                {
                    Write-Error "`"$_`" is not a valid Common Parameter."
                }

            }
        $codeString = @'
            $hash = @{}

'@
        foreach ($name in $vcp)
        {
            $codeString = $codeString + @"
            if ( `$PSCmdlet.MyInvocation.BoundParameters.Keys -Contains '$name' )
            {
                `$hash['$name'] = `$PSCmdlet.MyInvocation.BoundParameters['$name']
            }

"@
        }
        $codeString = $codeString + @'
            $hash
'@

        if ( $Code ) { return $codeString }

        [scriptblock]::Create($codeString)
    }
}

function NoParams
{
    [CmdletBinding()]
    param()
    process{}
}

Function Get-CommonParameterNames
{
    [CmdletBinding()]
    param()
    process
    {
        if ( $PSVersionTable.PSVersion.Major -ge 3 )
        {
            [System.Management.Automation.PSCmdlet]::CommonParameters+`
            [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        }
        else
        {
            (Get-Command NoParams).Parameters.Keys
        }
    }
}

function Publish-Failure
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory                       = $true,
                   Position                        = 1,
                   ValueFromPipelineByPropertyName = $true)]
        [string[]]
        $ArgumentList='Unspecified Error',

        [Parameter(Position                        = 2,
                   ValueFromPipelineByPropertyName = $true)]
        [Type]
        $ExceptionType=[System.Exception],

        [Parameter(Position                        = 3,
                   ValueFromPipelineByPropertyName = $true)]
        [string]
        [ValidateSet('Error','Verbose','Throw')]
        [Alias('fa')]
        $FailAction='Error',

        [switch]
        $AsCode
    )
    process
    {
        switch ($FailAction) {
            'Error' {
                $code = "Write-Error '$($ArgumentList[0])'"
            }
            'Verbose' {
                $code = "Write-Verbose '$($ArgumentList[0])'"
            }
            'Throw' {
                $argumentListString = ConvertTo-PsLiteralString $ArgumentList
                $code = "throw New-Object -TypeName $ExceptionType -ArgumentList $argumentListString"
            }
        }

        if ( $AsCode )
        {
            return $code
        }

        return [scriptblock]::Create($code)
    }
}
